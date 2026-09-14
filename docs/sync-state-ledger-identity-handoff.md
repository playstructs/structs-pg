# sync-state handoff: ledger identity, running balances, work list

This document hands the sync-state team the database changes shipped in the
`*-20260914-*` sqitch changes that follow `view-work-20260914-filterable-unions`,
explains what the production database currently shows about sync-state's
behaviour, and lists the sync-state work each change unlocks. `structs-pg`
owns DDL, indexes, constraints, grants and the nightly reconciler; sync-state
owns every write to `structs.ledger` and `structs.api_*`.

The changes are additive and nullable. Nothing in this delivery breaks the
sync-state build that is running today; it keeps working unchanged until the
team ships the items below.

## 1. What production shows (2026-09-14)

Numbers are from `pg_stat_*` counters since the 2026-08-25 stats reset unless
stated otherwise. `pg_stat_statements` is not loaded on the server, so these
are table/index counters plus live sampling, not per-statement stats.

### 1.1 Handler errors: every struct delete since 2026-08-24 is skipped

`sync_state.handler_error_log` holds 106,507 rows, none resolved. By
composite key and severity:

```
composite_key                                               severity  rows     first        last
structs.structs.EventDelete.objectId                        warn      106,393  2026-08-24   2026-09-14 (ongoing)
structs.structs.EventPlanetAttribute.planetAttributeRecord  error          88  2026-09-04   2026-09-04
structs.structs.EventStructType.structType                  error          22  2026-06-15   2026-06-15
structs.structs.EventGrid.gridRecord                        warn            4  2026-05-27   2026-06-15
```

**EventDelete.objectId (warn, ongoing, 2–6k per day).** First failure at
height 2,275,051 on 2026-08-24 13:45 UTC, i.e. with the v0.21 chain upgrade.
Sample row (`tx_index` and `msg_index` are NULL: these are end-block events):

```
height=2614299 event_index=54
payload: "\"5-262312\""
error:   skip with warn: delete: objecttype.Parse: "\"5-262312\"" bad type id:
         strconv.Atoi: parsing "\"5": invalid syntax
```

Since v0.21 the `objectId` attribute value arrives JSON-string-encoded
(quotes included) and the handler passes the quoted form to
`objecttype.Parse`, so every struct delete is dropped. Visible consequences:

- `structs.struct` has 282,854 rows; 225,867 (80%) have `is_destroyed = true`.
- `view.work` scans `structs.struct` three times per read (BUILD, MINE and
  REFINE branches), so this dead weight is paid on every work-list request.
- `deploy/view-work-20260203-exclude-destroyed.sql` exists in the working tree
  as a workaround for symptoms of this bug.

Ask: decode the attribute as a JSON string before `objecttype.Parse` (check
whether other v0.21 attributes changed encoding the same way), then replay
from height 2,275,051 so the deletes apply. Confirm with the webapp team
whether destroyed structs should be deleted or kept as tombstones; today they
are retained by accident.

**EventPlanetAttribute.planetAttributeRecord (error, 88 events, heights
2,470,392–2,470,599, 2026-09-04).** Sample payload
`{"attributeId": "12-2-28571", "value": "2470392"}`; error
`planet_attribute upsert id=12-2-28571: null value in column "attribute_type"
violates not-null constraint`. This is the window right after
`table-attribute-type-20260904-not-null` was deployed, before the handler
set `attribute_type` on upserts. Severity `error` means those 88 planet
mine-clock (`12-`) writes were lost, not skipped-with-fallback. The handler
is fixed (no recurrence), but the rows were never re-applied. Ask: replay
heights 2,470,392–2,470,599, or recompute the `12-*` and `13-*` planet
attributes for the affected planets.

**EventStructType.structType (error, 22 events, height 1,173,255,
2026-06-15).** `struct_type upsert id=N: column "generating_rate_p" of
relation "struct_type" does not exist`. A handler ahead of the schema for one
block; every struct type at that height was rejected. Long since superseded
by later struct-type events, but confirm `structs.struct_type` matches chain
state for all 22 ids (the sample payload has `id: "1"`, Command Ship).

**EventGrid.gridRecord (warn, 4 events, May–June).** Payload
`{"attributeId": "2-", "value": "0"}`: an attribute id with an empty object
id, rejected correctly. Likely a chain-side artefact; worth a look while in
that code, no data impact.

All 106,507 rows carry a full `stack` text, which is why the table is 47 MB.
Consider not storing the stack for `warn` rows once a key has been seen, or
resolving rows in bulk after each fix:

```sql
UPDATE sync_state.handler_error_log
   SET resolved_at = now(), resolved_by = 'sync-state/<ticket>'
 WHERE composite_key = 'structs.structs.EventDelete.objectId'
   AND resolved_at IS NULL;
```

Queries used above, for re-running after fixes:

```sql
SELECT composite_key, severity, count(*), min(created_at)::date, max(created_at)::date
  FROM sync_state.handler_error_log
 WHERE resolved_at IS NULL
 GROUP BY 1, 2 ORDER BY 3 DESC;

SELECT id, height, tx_index, msg_index, event_index, payload, error
  FROM sync_state.handler_error_log
 WHERE composite_key = 'structs.structs.EventDelete.objectId'
 ORDER BY created_at DESC LIMIT 5;
```

### 1.2 The inventory recompute is proportional to address history

Per block, sync-state runs (captured live):

```sql
INSERT INTO structs.api_inventory(owner_type, owner_id, denom, balance)
SELECT 'address', l.address, l.denom,
       SUM(CASE l.direction WHEN 'credit' THEN l.amount_p ELSE -l.amount_p END)
  FROM structs.ledger l
 WHERE l.address = ANY($1::varchar[])
 GROUP BY l.address, l.denom
```

That is correct and index-backed, but two addresses hold 294k and 133k of the
1.02M ledger rows. Whenever one of them is dirty the statement re-reads
~300k rows across all 25 ledger chunks (~180 MB of buffer hits, ~180 ms) to
produce ~13 output rows, and the planner underestimates the per-chunk row
count by ~75x. This is the pattern §3 replaces with a running balance.

Historically the ledger has been sequentially scanned ~3.5M times per chunk
(1.64 trillion tuples). Those counters are flat now, so that was the pre-`api_*`
request-path views and/or backfills, but it shows how fast a full-ledger read
on a hot path adds up.

### 1.3 Possible duplicate ledger rows

23,510 groups of ledger rows are byte-identical on
`(block_height, address, counterparty, action, direction, denom, amount_p)`
within one block. Some are certainly legitimate (two identical transfers in a
block); some may be replays. Without a source-event identity the database
cannot tell, and neither can sync-state. §2 fixes that going forward; please
sample a few groups against chain data to judge whether a one-off cleanup is
needed before backfilling balances.

### 1.4 `unknown_event_log` churn

`sync_state.unknown_event_log` has 146 rows and has received 8.3M updates,
none of them HOT, because `unknown_event_log_count_idx` indexed the `count`
column that every update increments. Autovacuum has run 74k times on this
600 kB table. The index had zero scans, so it has been dropped
(`index-sync-state-20260914-drop-unknown-event-count-idx`).

Nearly all of the churn comes from five Cosmos SDK distribution attributes
that appear in every block and will never be handled:

```
composite_key         count       first_seen_height  last_seen_height
commission.validator  17,993,553  258,301            2,614,462
rewards.validator     17,993,553  258,301            2,614,462
rewards.mode          17,993,553  258,301            2,614,462
commission.mode       17,993,553  258,301            2,614,462
rewards.amount        17,993,553  258,301            2,614,462
```

Asks:

- Remove the matching `CREATE INDEX IF NOT EXISTS unknown_event_log_count_idx`
  from sync-state's `bootstrap.sql` so the doctor probe does not flag it.
- Add an ignore list for known-irrelevant SDK event types (`commission`,
  `rewards`, and whatever else in the table is `cosmos.*`/`ibc.*`) so they
  never reach `unknown_event_log`, or batch the counter update once per block
  instead of once per attribute. Either removes ~5 row updates per block.

## 2. Ledger source-event identity

Change: `table-ledger-20260914-source-event-identity`.

`structs.ledger` gains four nullable columns and one unique index:

```sql
chain_id     CHARACTER VARYING
tx_index     INTEGER      -- -1 for begin/end-block events
msg_index    INTEGER      -- -1 when not inside a message
event_index  INTEGER

UNIQUE INDEX ledger_source_event_uidx (time, chain_id, tx_index, msg_index, event_index)
CHECK ledger_source_event_all_or_none_chk  -- all four NULL or all four NOT NULL
```

`time` is part of the key because TimescaleDB requires the partitioning column
in every unique index on a hypertable. That is harmless: every ledger row in
production carries the block time exactly (116,631 of 116,631 rows checked
over the last seven days match `sync_state.block_log.block_time`), so `time`
is a function of the height. Keep it that way; never write `now()`.

Rows with a NULL identity never conflict with anything (NULLS DISTINCT), so
the index has no effect on the current sync-state until it starts populating
the columns. Partially populated rows are rejected by the CHECK.

### 2.1 Write pattern

```sql
INSERT INTO structs.ledger
    (time, address, counterparty, amount_p, block_height, action, direction, denom,
     chain_id, tx_index, msg_index, event_index)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
ON CONFLICT (time, chain_id, tx_index, msg_index, event_index) DO NOTHING
RETURNING address, denom,
          CASE direction WHEN 'credit' THEN amount_p ELSE -amount_p END AS delta;
```

A replayed event inserts nothing and returns nothing. Everything downstream
(balance deltas, notifications you may add later) should key off the
`RETURNING` set, so replay is idempotent by construction. `amount_p` is the
exact signed base-unit amount; never derive deltas from the generated
`amount` column.

Multiple ledger rows from one chain event (for example both legs of a
transfer, or fee rows) need distinct identities. If one event produces N rows,
either give each row a distinct `event_index` sub-sequence agreed within the
team, or extend the identity with a `leg` column before cutover; do not reuse
the same tuple for two rows because the second will be silently dropped.

### 2.2 Legacy rows and full replays

Existing rows keep `chain_id IS NULL`. Two consequences:

- A full replay from genesis after cutover must start from an empty ledger
  (or `DELETE FROM structs.ledger WHERE chain_id IS NULL` first). Otherwise
  every legacy row is re-created with an identity next to its identity-less
  twin and all balances double. The existing `sync_state.genesis_log` guard
  only covers `action = 'genesis'` rows.
- The columns can become `NOT NULL` (a later `structs-pg` change) only once
  no NULL rows remain, i.e. after such a replay or a backfill that assigns a
  synthetic identity (`chain_id = 'legacy', tx_index = -1, msg_index = -1,
  event_index = id`). Tell us which route you take.

`structs.ledger.address` now has a statistics target of 1000. Nothing to do
on your side; the next autoanalyze picks it up and per-address plans on the
hot addresses stop being under-estimated.

## 3. `api_inventory` as a running balance

No schema change to `structs.api_inventory`; this is a sync-state behaviour
change enabled by §2. Replace the per-block recompute with an upsert of the
deltas returned by the ledger insert, in the same transaction as the block
writes:

```sql
WITH new_rows AS (
    INSERT INTO structs.ledger (...)
    VALUES (...), (...)
    ON CONFLICT (time, chain_id, tx_index, msg_index, event_index) DO NOTHING
    RETURNING address, denom,
              CASE direction WHEN 'credit' THEN amount_p ELSE -amount_p END AS delta
)
INSERT INTO structs.api_inventory (owner_type, owner_id, denom, balance)
SELECT 'address', address, denom, SUM(delta)
  FROM new_rows
 WHERE address IS NOT NULL
 GROUP BY address, denom
ON CONFLICT (owner_type, owner_id, denom)
DO UPDATE SET balance = structs.api_inventory.balance + EXCLUDED.balance;
```

Cost per block is proportional to rows in the block, not to address history.

### 3.1 Player rows

Derive `owner_type = 'player'` rows from address rows instead of from the
ledger. A player has a handful of addresses, so after the address upsert:

```sql
INSERT INTO structs.api_inventory (owner_type, owner_id, denom, balance)
SELECT 'player', pa.player_id, i.denom, SUM(i.balance)
  FROM structs.player_address pa
  JOIN structs.api_inventory i
    ON i.owner_type = 'address' AND i.owner_id = pa.address
 WHERE pa.player_id = ANY($1::varchar[])          -- players owning a dirty address
 GROUP BY pa.player_id, i.denom
ON CONFLICT (owner_type, owner_id, denom)
DO UPDATE SET balance = EXCLUDED.balance;
```

Delete player/denom rows that no longer appear in that result for the dirty
players (a player whose last address was re-associated). When a
`player_address` row changes, dirty both the old and the new player and run
the same statement; no ledger read is needed. Zero-balance rows may be kept
or deleted; the reconciler treats "0" and "missing" as equal.

### 3.2 Initial backfill

One-off, before enabling the incremental path, in one transaction:

```sql
DELETE FROM structs.api_inventory;
INSERT INTO structs.api_inventory (owner_type, owner_id, denom, balance)
SELECT 'address', address, denom,
       SUM(CASE direction WHEN 'credit' THEN amount_p ELSE -amount_p END)
  FROM structs.ledger
 WHERE address IS NOT NULL AND denom IS NOT NULL
 GROUP BY address, denom;
INSERT INTO structs.api_inventory (owner_type, owner_id, denom, balance)
SELECT 'player', pa.player_id, i.denom, SUM(i.balance)
  FROM structs.api_inventory i
  JOIN structs.player_address pa ON pa.address = i.owner_id
 WHERE i.owner_type = 'address'
 GROUP BY pa.player_id, i.denom;
```

Then run `SELECT * FROM structs.api_inventory_reconcile(false);` and expect
zero rows before switching the block loop over.

Keep updating `structs.api_refresh_state` for model `inventory` last in the
transaction, as today.

## 4. Reconciliation: `api_inventory_reconcile()` and `api_inventory_drift`

Change: `table-api-inventory-20260914-reconciliation`.

The only place a full ledger aggregate belongs is a scheduled check.

- `structs.api_inventory_reconcile(p_log boolean DEFAULT true)` recomputes
  every `(owner_type, owner_id, denom)` balance from `structs.ledger` in one
  snapshot, compares with `structs.api_inventory`, and returns the mismatches
  (`api_balance`, `ledger_balance`; NULL means the side had no row). It never
  writes `api_inventory`.
- With `p_log = true` it also appends the mismatches to
  `structs.api_inventory_drift` under one `checked_at`, tagged with
  `api_refresh_state.source_height` for `inventory`, and prunes drift older
  than 90 days.
- pg_cron job `api_inventory_reconciler` runs it daily at 03:17 UTC.
- `structs_indexer` has `EXECUTE` on the function and `SELECT, UPDATE, DELETE`
  on the drift table.

Asks:

- After the backfill and after any replay, run
  `SELECT * FROM structs.api_inventory_reconcile(false);` and expect no rows.
- Consume the drift table. Suggested loop: for each row in the latest
  `checked_at` batch, recompute that key from the ledger (the old per-key
  query is fine here, it runs for a handful of rows), upsert it, then delete
  the drift row. Alert if a batch is non-empty two nights running; that means
  the incremental path has a bug, not just a race.
- The function disables parallel workers because the container's `/dev/shm`
  is 64 MB (see §7). Expect ~2 s on the current 1M-row ledger.

## 5. `structs.api_work`

Changes: `table-api-work-20260914-current-state`,
`role-structs-indexer-20260914-api-work-and-drift`,
`role-structs-webapp-20260914-api-work`.

`view.work` (BUILD / MINE / REFINE / RAID list) is rebuilt from `struct`,
`struct_attribute`, `struct_type`, `grid`, `planet`, `planet_attribute` and
`fleet` on every read. `SELECT count(*) FROM view.work` costs ~180 ms and
~145k buffer hits and the webapp calls it several times a minute; it is the
largest steady-state CPU consumer on the server right now.

`structs.api_work` has exactly the `view.work` columns and types plus
`source_height` and `updated_at`, primary key `(category, object_id, target_id)`,
and indexes by `player_id`, `planet_id` and `category`. It is empty until
sync-state backfills it. `view.work` keeps its live definition until then; a
later `structs-pg` change re-points the view at the table, as
`view-inventory-20260914-read-api-current-state` did for inventory, so the
webapp does not change.

### 5.1 Semantics

`view.work` is the specification. Use it directly:

- Backfill: `INSERT INTO structs.api_work (object_id, player_id, target_id,
  category, block_start, difficulty_target, location_type, location_id,
  planet_id, source_height) SELECT *, $height FROM view.work;`
- Per block: collect dirty struct ids and dirty planet ids, then within the
  block transaction delete their rows and re-insert from the view:

```sql
DELETE FROM structs.api_work
 WHERE object_id = ANY($structs) OR planet_id = ANY($planets)
    OR target_id = ANY($planets);
INSERT INTO structs.api_work (object_id, player_id, target_id, category,
    block_start, difficulty_target, location_type, location_id, planet_id, source_height)
SELECT w.*, $height
  FROM view.work w
 WHERE w.object_id = ANY($structs) OR w.planet_id = ANY($planets)
    OR w.target_id = ANY($planets);
```

`view-work-20260914-filterable-unions` made every branch of the view start
from `struct` (or `planet`) so those predicates push down and each call
touches only the dirty rows.

Inputs that dirty a struct: its creation or deletion, any change to its
`status` attribute (`struct_attribute` id `1-<struct>`), its build clock
(`2-<struct>`), its `owner`, `type`, `location_type` or `location_id`, and a
`struct_type` change (dirty every struct of that type). Inputs that dirty a
planet: `planet_attribute` shield `0-<planet>`, raid clock `10-<planet>`,
mine clock `12-<planet>`, refine clock `13-<planet>`, `grid` `0-<planet>`
(planet ore), `planet.location_list_start`, and `fleet.owner` for the fleet
at `location_list_start`. `grid` `0-<player>` (player ore, used by the
REFINE branch) dirties every struct owned by that player.

Add a `work` row to `structs.api_refresh_state` and update it last.

## 6. Rollout order

1. `structs-pg` deploys the 20260914 changes (auto-migrate picks them up from
   `main`). This is a hard prerequisite for step 3, not a preference: without
   `ledger_source_event_uidx` every `INSERT ... ON CONFLICT (time, chain_id,
   tx_index, msg_index, event_index)` fails with "no unique or exclusion
   constraint matching the ON CONFLICT specification", and writes to
   `api_work` or reads of `api_inventory_drift` fail on missing relations.
   Confirm with `SELECT to_regclass('structs.ledger_source_event_uidx'),
   to_regclass('structs.api_work');` before enabling the new code path.

   The reverse is safe: nothing sync-state does today breaks once these are
   deployed. The reconciler will start logging drift nightly; until §3 ships
   it acts as a check on the current recompute path, which is useful on its
   own. If `Bootstrap()` still executes `bootstrap.sql` rather than only
   probing it, a sync-state restart will recreate `unknown_event_log_count_idx`
   until §1.4 lands; harmless, but it undoes that fix.
2. sync-state: §1.1 delete fix and replay; §1.4 bootstrap.sql index removal.
3. sync-state: §2 identity writes, §3 running balance with backfill, §4 drift
   consumption, §5 `api_work` backfill and maintenance. These can ship in any
   order but §3 depends on §2.
4. `structs-pg`, after sync-state confirms `api_work` is backfilled and the
   reconciler has been clean for a few nights:
   - re-point `view.work` at `structs.api_work`;
   - `SET NOT NULL` on the identity columns (see §2.2);
   - add a compression policy on `structs.ledger`
     (`segmentby address, denom`, compress after 30 days). This is
     deliberately deferred: while the per-block recompute still reads all
     chunks, compressed chunks would make it slower, not faster.

## 7. Items outside both repos

Found during the review; listed so they are not lost. Owners in brackets.

- [docker-structs-guild] The `structs-pg` service runs with Docker's default
  64 MB `/dev/shm`. Parallel hash joins allocate dynamic shared memory there
  and fail with `could not resize shared memory segment ... No space left on
  device`; one such failure was reproduced during the review. Set
  `shm_size: 1g` on the service. Until then do not raise
  `max_parallel_workers_per_gather` above the current 1.
- [structs-pg image] Add `pg_stat_statements` to `shared_preload_libraries`
  in the image's `postgresql.conf`; the
  `extension-pg-stat-statements-20260914` change creates the extension
  automatically once the library is loaded. Everything in §1 was inferred
  from table counters and sampling; the next review should read real
  statement statistics.
- [structs-pg image / ops] `structs`, `structs_indexer` and `structs_webapp`
  are all `SUPERUSER`. Grants in this repo are therefore documentation, not
  enforcement. Plan a `NOSUPERUSER` migration for at least `structs_webapp`.
- [structs-webapp] Stop calling `SELECT count(*) FROM view.work` on request
  paths (or read it from `api_work` once §5 lands). The player activity query
  on `structs.planet_activity` filters with `jsonb @>` and no time bound, so
  it cannot exclude chunks; that table is already 906 MB and the query cost
  grows linearly with it. Add a time predicate.
- [structs-pg] Deployed with this delivery for the webapp role:
  `statement_timeout = 60s`, `idle_in_transaction_session_timeout = 5min`.
  Every sampled webapp statement finishes well under a second. Tell us if
  anything legitimately runs longer.

## 8. Verification queries

```sql
-- identity is being populated and no partial rows exist
SELECT count(*) FILTER (WHERE chain_id IS NULL)     AS legacy_rows,
       count(*) FILTER (WHERE chain_id IS NOT NULL) AS identified_rows
  FROM structs.ledger;

-- ledger writes are idempotent: re-running a block's inserts returns 0 rows
-- (use the RETURNING count from the block loop)

-- inventory matches the ledger
SELECT * FROM structs.api_inventory_reconcile(false);

-- drift history
SELECT checked_at, count(*) FROM structs.api_inventory_drift
 GROUP BY 1 ORDER BY 1 DESC LIMIT 14;

-- api_work matches view.work while both exist
SELECT count(*) FROM (
    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id FROM view.work
    EXCEPT
    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id FROM structs.api_work
) d;

-- delete handler is fixed: no new EventDelete warns
SELECT count(*) FROM sync_state.handler_error_log
 WHERE composite_key = 'structs.structs.EventDelete.objectId'
   AND created_at > now() - interval '1 day';
```
