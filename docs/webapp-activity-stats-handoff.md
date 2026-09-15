# Webapp handoff: activity attribution, game stats, ledger paging, connections

Audience: structs-webapp team. Companion documents:
`docs/sync-state-activity-stats-handoff.md` (docker / sync-state side of the
same delivery) and `docs/sync-state-ledger-identity-handoff.md` (the previous
delivery; §7 lists items that were already pointed at the webapp).

Everything in §1–§4 is deployed by the `*-20260915-*` changes in
`sqitch.plan`. Nothing here changes an existing table the webapp reads; the
new relations sit beside them. The webapp can repoint one endpoint at a
time. `structs_webapp` has `SELECT` on every relation named below.

## 0. What was measured and why this exists

Sampling `pg_stat_activity` and running `EXPLAIN (ANALYZE, BUFFERS)` on the
webapp's statements against production (read-only):

| Endpoint / statement | Today | Through the new relations |
|---|---|---|
| `GET /api/planet-activity/player/{id}/page/{n}` | 427 ms, 1.05M buffers, parallel seq scan of all 25 `planet_activity` chunks, per page | 6.9 ms, index-ordered `LIMIT 100` |
| `GET /api/planet-activity/stats` (30 d / day) | 580 ms, scans 30 days of rows | sums ~3k rows of a continuous aggregate |
| `GET /api/stat/{metric}/aggregate/range` (7 d / hour) | 301 ms, 108k buffers; the `seed` CTE scans all history before the window | range scan of `stat_rollup` (~170 rows) |
| `view.permission_player WHERE player_id = …` | seq scan, 236k rows | 0.27 ms |
| Ledger list endpoints, deep pages | whole history read + top-N sort per page via the `player_address` join; 22 MB temp spill past `OFFSET` ~80k | see §4 |
| Connections | ~1,110 new sessions/min, ~5 statements each, `SET NAMES` on every connect | see §5 |

The per-player feed is 12% of sampled activity and its cost grows linearly
with `planet_activity` (+30–60k rows/day).

## 1. Per-player activity feed

### 1.1 What changed in the database

`structs.planet_activity` has no player column, so `planetActivityByPlayer()`
reconstructs attribution on every read with six OR'd predicates over
`detail` JSON and *current* ownership.

The attribution rules now live in one function,
`structs.planet_activity_players(category, planet_id, detail) RETURNS TABLE
(player_id, role)`, and are applied once at insert time by a trigger that
writes `structs.planet_activity_player`:

```
structs.planet_activity_player
  time         timestamptz   -- same (time, planet_id, seq) as the parent row
  planet_id    varchar
  seq          integer
  player_id    varchar
  role         text          -- see below
  category     structs.grass_category
  block_height bigint
  PRIMARY KEY (time, planet_id, seq, player_id, role)
  INDEX planet_activity_player_feed_idx          (player_id, block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
  INDEX planet_activity_player_category_feed_idx (player_id, category, block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
```

One row per (activity row, player, role). Roles, and how they map to the
branches in `planetActivityPlayerBranches()`:

| category | role | source | webapp branch today |
|---|---|---|---|
| `struct_attack` | `attacker` | `detail.attackerPlayerId` | same |
| `struct_attack` | `target` | each `detail.eventAttackShotDetail[].targetPlayerId` | same |
| `struct_status`, `struct_health`, `struct_move`, `struct_block_*_start` | `owner` | owner of `detail.struct_id` | same |
| `struct_block_ore_mine_start`, `struct_block_ore_refine_start` with `detail.planet_id` and no `struct_id` | `planet_owner` | owner of the planet | **not attributed today** (~61k rows, 22% of those two categories) |
| `struct_defense_add`, `struct_defense_remove` | `defender` | owner of `detail.defender_struct_id` | same |
| `struct_defense_add`, `struct_defense_remove` | `protected` | owner of `detail.protected_struct_id` | **new** |
| `raid_status`, `fleet_arrive`, `fleet_depart` | `fleet_owner` | owner of `detail.fleet_id` | same |
| `raid_status`, `fleet_arrive`, `fleet_depart`, `shield_change`, `block_raid_start` | `planet_owner` | owner of `planet_id` | same |

Ownership is resolved through `structs.player_object` (which matched
`struct.owner`, `fleet.owner` and `planet.owner` on every row when checked)
with the base tables as fallback.

Two semantic differences from the current query, both deliberate:

1. Ownership is recorded **as of the event**. Today a struct that changes
   hands moves its whole history to the new owner's feed; with the side table
   history stays with whoever owned it at the time. History (2.3M rows) was
   backfilled using current ownership, so for old rows the two agree; the
   difference only appears for ownership changes after the deploy.
2. The two **additions** above (`planet_owner` on planet-level clocks,
   `protected`). Verified on production for three players over the two most
   recent chunks: webapp-set minus side-table-set = 0 rows; side-table-set
   minus webapp-set = 9 rows, all planet-keyed `struct_block_ore_refine_start`.

### 1.2 Query to use

Keep the endpoint's contract (`page`, `order`, `since_height`, optional
`category`) and replace the `FROM` / `WHERE` with a join through the side
table:

```sql
SELECT a.time, a.seq, a.planet_id, a.block_height, a.category::text AS category, a.detail
  FROM structs.planet_activity_player p
  JOIN structs.planet_activity a
    ON a.time = p.time AND a.planet_id = p.planet_id AND a.seq = p.seq
 WHERE p.player_id = :player_id
   -- optional:
   -- AND p.category = CAST(:category AS structs.grass_category)
   -- AND p.role = :role
   -- AND p.block_height > :since_height
 ORDER BY p.block_height DESC NULLS LAST, p.time DESC, p.planet_id DESC, p.seq DESC
 LIMIT 100 OFFSET :offset;
```

Notes:

- Order by the **`p.`** columns and add `NULLS LAST` to `block_height DESC`
  (rows before 2026‑05‑22 have NULL `block_height`; the index is declared
  `DESC NULLS LAST`, matching the existing `planet_activity` read indexes).
  For `order=asc` use `p.block_height ASC NULLS FIRST, p.time ASC, p.planet_id ASC, p.seq ASC`.
- A player with more than one role on the same row (attacker who is also the
  planet owner) has two side rows. Either `SELECT DISTINCT` on the parent key
  or, simpler, filter `p.role` when the caller asks for one; when no role is
  requested add `DISTINCT ON (p.block_height, p.time, p.planet_id, p.seq)`
  or accept the duplicate (it is rare: 574k side rows for 505k parent rows,
  and most of that is `defender`+`protected` on the same player).
- The join back to `planet_activity` is on its unique
  `(time, planet_id, seq)` index; the measured plan is a nested loop of 100
  index lookups.

**Update 2026-09-15, after your cutover shipped — please switch the join to
`LATERAL`.** The shape above works (page 1 for the busiest player: 3 ms) but
the planner probes every `planet_activity` chunk for every side row (25
chunks × rows, no chunk exclusion), and deep pages get expensive (offset
2400: 147 ms). It also blocks compressing `planet_activity` history: on a
compressed chunk that plan decompresses the whole chunk (1,000 ms for the
same page, measured on a rolled-back `compress_chunk`). Pick the page keys
first, then fetch each parent row with a `LATERAL` subquery; Timescale then
excludes chunks at runtime:

```sql
SELECT a.time, a.seq, a.planet_id, a.block_height, a.category::text AS category, a.detail
  FROM (
        SELECT p.block_height, p.time, p.planet_id, p.seq
          FROM structs.planet_activity_player p
         WHERE p.player_id = :player_id
           -- optional: AND p.category = ..., AND p.role = ..., AND p.block_height > ...
         GROUP BY p.block_height, p.time, p.planet_id, p.seq      -- replaces DISTINCT ON
         ORDER BY p.block_height DESC NULLS LAST, p.time DESC, p.planet_id DESC, p.seq DESC
         LIMIT 100 OFFSET :offset
       ) k
 CROSS JOIN LATERAL (
        SELECT a.*
          FROM structs.planet_activity a
         WHERE a.time = k.time AND a.planet_id = k.planet_id AND a.seq = k.seq
         LIMIT 1
       ) a
 ORDER BY k.block_height DESC NULLS LAST, k.time DESC, k.planet_id DESC, k.seq DESC;
```

Same rows as the `DISTINCT ON` form (verified row-for-row on production).
Measured for the same player: page 1, offset 2400 and offset 4000 all 6–9 ms,
and the same 6–9 ms with a compressed chunk in the path (`Chunks excluded
during runtime: 24`). Once `pg_stat_statements` shows this shape from
`structs_webapp`, we enable compression on `planet_activity` (branch
`phase-2-activity-compression`; its deploy guard checks for exactly that).
- New capability for the API if wanted: `role` filter
  (`attacker|target|owner|planet_owner|defender|protected|fleet_owner`), and
  "attacks on me" = `category = 'struct_attack' AND role = 'target'`.
- `planet_activity_player_daily` (see §2.2) gives per-player counts by
  category and role per day without touching either table.

### 1.3 What can be removed after cutover

Once `planetActivityByPlayer()` no longer reads `detail` predicates:

- `planetActivityPlayerBranches()` and the five `*Predicate()` helpers.
- In the database: `planet_activity_detail_gin` and
  `planet_activity_block_time_planet_seq_idx` (160 MB together, ~100 scans
  each since 09-14 against 26M on the unique index) are dropped by
  `index-planet-activity-20260915-drop-feed-indexes` on `main`, now that
  your cutover is visible in `pg_stat_statements`. Compression of
  `planet_activity` chunks older than 30 days waits for the `LATERAL` feed
  shape in §1.2.

## 2. Activity stats

### 2.1 Global / per-category / per-planet: continuous aggregates

```
structs.planet_activity_hourly (bucket timestamptz, category grass_category, planet_id varchar, count bigint)
    materialized only; refreshed every 10 min for the last 3 days (lag ≤ 10 min)
structs.planet_activity_daily  (bucket timestamptz, category grass_category, planet_id varchar, count bigint)
    hierarchical on _hourly; real-time for the current day (reads _hourly, not the raw table)
```

`planetActivityStats(?category, ?bucket)` becomes:

```sql
-- bucket = '1h'
SELECT bucket, category::text AS category, sum(count) AS count
  FROM structs.planet_activity_hourly
 WHERE bucket >= now() - INTERVAL '30 days'
   -- AND category = CAST(:category AS structs.grass_category)
 GROUP BY bucket, category
 ORDER BY bucket, category;

-- bucket = '1d' (default)
SELECT bucket, category::text AS category, sum(count) AS count
  FROM structs.planet_activity_daily
 WHERE bucket >= date_trunc('day', now() - INTERVAL '30 days')
 GROUP BY bucket, category
 ORDER BY bucket, category;
```

Same output columns as today. `bucket` is `time_bucket()` (UTC-aligned)
instead of `date_trunc()`; identical for hour and day in a UTC database.
Per-planet stats are the same query with `AND planet_id = :planet_id` and no
`sum` needed.

### 2.2 Per-player stats

```
structs.planet_activity_player_daily (bucket timestamptz, player_id varchar, category grass_category, role text, count bigint)
    real-time for the current day
```

```sql
SELECT bucket, category::text AS category, role, count
  FROM structs.planet_activity_player_daily
 WHERE player_id = :player_id AND bucket >= date_trunc('day', now() - INTERVAL '30 days')
 ORDER BY bucket, category, role;
```

This did not exist before (attribution was read-time only). Attacks made =
`struct_attack/attacker`, attacks received = `struct_attack/target`, raids
against the player's planets = `raid_status/planet_owner`, and so on.

## 3. Stat series (`StatReadManager::getStatAggregate`)

### 3.1 What changed

The `stat_*` hypertables record an object's value only when it changes, so
`GET /api/stat/{metric}/aggregate/range` reconstructs the last-known value of
every object at every bucket close (LOCF). The `seed` CTE that anchors the
running total scans all history before `start`; the cost is unbounded and
dominated by how much history exists, not by the requested range.

The last-known value of every object *right now* is the current state in
`structs.grid` / `structs.struct_attribute`. So:

```
structs.stat_rollup
  bucket      timestamptz              -- hour start; value is as of the hour's close
  metric      text                     -- FK structs.stat_rollup_metric
  object_type structs.object_type
  sum         numeric                  -- Σ last-known value over all objects
  population  bigint                   -- number of objects
  samples     bigint                   -- stat_* rows written in that hour
  source      text                     -- 'snapshot' (hourly cron from current state) | 'backfill' (LOCF over history)
  PRIMARY KEY (metric, object_type, bucket)

structs.stat_rollup_metric (metric, stat_table, family, source_table, attribute_type, object_type)
  -- database copy of FAMILY_ONE_TABLES / FAMILY_TWO_TABLES / FAMILY_TWO_OBJECT_TYPES
```

`stat_rollup_snapshot()` runs at :02 every hour and writes the bucket that
just closed. History was backfilled once with the same LOCF computation your
query uses (ported verbatim), so the series is continuous.

Verified on production: for `ore/planet`, `ore/player` and
`connection_count/substation` the snapshot equals the LOCF result exactly
(sum and population). For `struct_health/struct` the sum differed by 2
(a change between the two computations) but **population differs**: LOCF
counts every struct that ever reported (283k); the snapshot counts structs
currently in `struct_attribute` (94k). `avg = sum / population` for struct
metrics therefore steps at the seam between backfilled and snapshot rows
(2026‑09‑15). Objects are never removed from `grid`, so `ore`, `fuel`,
`capacity`, `load`, `power`, `structs_load`, `connection_*` do not have this
step.

### 3.2 Query to use

```sql
-- bucket = '1h'
SELECT bucket,
       sum,
       CASE WHEN population > 0 THEN sum / population END AS avg,
       population,
       samples
  FROM structs.stat_rollup
 WHERE metric = :metric
   AND object_type = CAST(:object_type AS structs.object_type)   -- family two: the fixed type from FAMILY_TWO_OBJECT_TYPES
   AND bucket >= date_trunc('hour', to_timestamp(:start_ts))
   AND bucket <= date_trunc('hour', to_timestamp(:end_ts))
 ORDER BY bucket;

-- bucket = '1d': the day's value is its last hourly row (value at day close); samples are summed
SELECT DISTINCT ON (date_trunc('day', bucket))
       date_trunc('day', bucket) AS bucket,
       sum,
       CASE WHEN population > 0 THEN sum / population END AS avg,
       population,
       sum(samples) OVER (PARTITION BY date_trunc('day', bucket)) AS samples
  FROM structs.stat_rollup
 WHERE metric = :metric AND object_type = CAST(:object_type AS structs.object_type)
   AND bucket >= date_trunc('day', to_timestamp(:start_ts))
   AND bucket <  date_trunc('day', to_timestamp(:end_ts)) + INTERVAL '1 day'
 ORDER BY date_trunc('day', bucket), bucket DESC;
```

Same response shape (`bucket, sum, avg, population, samples`). Differences:
buckets with no objects are absent instead of present with NULL `sum`; the
newest hour is available a couple of minutes after it closes (the current,
unfinished hour is not present — the old query returned a partial value for
it). `getStatRange` (per-object series) is unchanged; it is already an index
range on `(object_index, time)`.

## 4. Ledger list endpoints

Not part of the new relations, but measured in the same review, and after
the 2026-09-15 catalog indexes these are the only `structs_webapp` statements
that still write temporary files. The player-scoped ledger page is:

```sql
SELECT l.time, l.id, l.address, ... FROM structs.ledger l
INNER JOIN structs.player_address pa
        ON pa.address = l.address AND pa.player_id = :player
ORDER BY l.time DESC, l.id DESC LIMIT :limit OFFSET :offset;
```

The sort direction already matches `ledger_address_time_id_idx (address,
time DESC, id DESC)`. The problem is the join: a player has several
addresses, and the planner cannot produce `time DESC` order across them from
a per-address index, so every page reads the player's entire history and
top-N sorts it. Measured for player `1-194` (136k rows, 2 addresses):
page 1 reads 14,398 buffers in 79 ms; the top-N heap reaches 28 MB at
`OFFSET 100000`, past `work_mem`, which is the 22 MB temp file logged per
page when someone pages to the tail of a long history. The planner also
estimates 561 rows for this join (actual 136k), so it never considers a
better plan.

1. Bound each address's scan before merging, with `LATERAL`:

   ```sql
   SELECT x.*
     FROM structs.player_address pa
    CROSS JOIN LATERAL (
          SELECT l.time, l.id, l.address, l.counterparty, l.amount, l.amount_p,
                 l.block_height, l.action::text AS action,
                 l.direction::text AS direction, l.denom
            FROM structs.ledger l
           WHERE l.address = pa.address
           ORDER BY l.time DESC, l.id DESC
           LIMIT :limit + :offset) x
    WHERE pa.player_id = :player
    ORDER BY x.time DESC, x.id DESC
    LIMIT :limit OFFSET :offset;
   ```

   Same rows, same order. Each address contributes at most
   `limit + offset` rows straight from the index, so the outer sort is
   bounded and never spills. Measured on the same player: page 1 1.2 ms /
   73 buffers (was 79 ms / 14,398); `OFFSET 5000` 8.9 ms (was 43 ms).
   The address-scoped `ledgerList*()` variants have the same shape with a
   single address and only need the `ORDER BY time DESC, id DESC` they
   already have.
2. Offer a keyset cursor instead of page numbers for deep history:
   `WHERE (time, id) < (:before_time, :before_id) ORDER BY time DESC, id DESC
   LIMIT 100` (inside the `LATERAL` for the player form), and cap `page`
   (e.g. 50) for the OFFSET form, the same way the planet-activity
   endpoints already use `KEYSET_SEQ`. Even with (1), `OFFSET 100000` still
   reads 100k index entries per address.

## 5. Connections

~1,110 new sessions per minute from `structs_webapp`, each running ~5
statements, of which one is Doctrine's `SET NAMES 'utf8'` on connect
(`Doctrine\DBAL\Driver\PDO\PgSQL\Driver` issues it when `charset` is set in
the DSN). Connection setup is a measurable share of the database's work.

Preferred: put pgbouncer (transaction mode) in front of `structs-pg` for the
webapp — that is in the docker handoff. Until then, or in addition:

- `doctrine.dbal.options: { !php/const PDO::ATTR_PERSISTENT: true }` keeps
  one connection per PHP-FPM worker (only appropriate without pgbouncer in
  transaction mode; with pgbouncer leave it off).
- Drop `charset` from `DATABASE_URL` — the server encoding is already UTF8,
  so `SET NAMES` is a no-op round trip.

`structs_webapp` now has `statement_timeout = 60s` and
`idle_in_transaction_session_timeout = 5min` (previous delivery); nothing
sampled comes close.

## 6. Cutover order and verification

1. Deploy `structs-pg` `*-20260915-*` (done when you read this; check with
   `SELECT change FROM sqitch.changes WHERE change LIKE '%20260915%'`).
2. Repoint, in any order, one endpoint per release if you like:
   `planetActivityByPlayer` (§1), `planetActivityStats` (§2), `getStatAggregate` (§3).
   Ledger ordering (§4) and connections (§5) are independent.
3. Done 2026-09-15: `planetActivityByPlayer` reads `planet_activity_player`,
   and the GIN / `block_time_planet_seq_idx` drop is on `main`. Remaining:
   switch the feed join to the `LATERAL` form in §1.2 and the ledger paging
   in §4. Compression of `planet_activity` follows the `LATERAL` change
   automatically (its deploy guard looks for that statement shape from
   `structs_webapp`).

Verification queries (run as `structs`; `structs_webapp` can run all but the
last one):

```sql
-- side table is live: rows within the last few minutes
SELECT max(time) FROM structs.planet_activity_player;

-- feed parity for one player against the current predicates (expect only the documented additions)
-- (use the six-branch query from planetActivityPlayerBranches() on the left)

-- caggs are fresh
SELECT view_name, materialized_only FROM timescaledb_information.continuous_aggregates WHERE view_schema = 'structs';
SELECT max(bucket) FROM structs.planet_activity_hourly;          -- within the last ~10-70 min

-- stat_rollup is being written hourly
SELECT metric, object_type, max(bucket), max(source) FROM structs.stat_rollup GROUP BY 1, 2 ORDER BY 1, 2;

-- attribution drift log (nightly 03:33; 'extra' from ownership changes is expected, 'missing' is not)
SELECT checked_at, state, count(*) FROM structs.planet_activity_player_drift GROUP BY 1, 2 ORDER BY 1 DESC;
```
