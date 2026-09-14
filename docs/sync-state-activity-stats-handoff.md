# Docker / sync-state handoff: activity attribution, game stats, operations

Audience: docker-structs-pg and sync-state team. Companion documents:
`docs/webapp-activity-stats-handoff.md` (what the webapp will read) and
`docs/sync-state-ledger-identity-handoff.md` (previous delivery; §5.1 and §7
of that document still apply and are repeated in §6 here).

Short version: **no sync-state code change is required for this delivery.**
The new relations are maintained by a database trigger, Timescale refresh
policies and `pg_cron`. What this document asks of you is (a) to know they
exist, (b) three small guardrails in sync-state's tooling, and (c) the Docker
/ image items in §5.

## 1. What was added and how it is fed

| Relation | Kind | Fed by | Read by |
|---|---|---|---|
| `structs.planet_activity_player` | hypertable, 7-day chunks | `AFTER INSERT` trigger `planet_activity_attribute` on `structs.planet_activity` | webapp per-player feed |
| `structs.planet_activity_players(category, planet_id, detail)` | function | — (the attribution specification) | trigger, backfill, reconciler |
| `structs.object_owner(object_id)` | function | — (`player_object`, fallback to `struct`/`fleet`/`planet`) | the above |
| `structs.planet_activity_hourly` / `_daily` | continuous aggregates | Timescale policies (10 min / 1 h) | webapp stats |
| `structs.planet_activity_player_daily` | continuous aggregate | Timescale policy (1 h) | webapp per-player stats |
| `structs.stat_rollup`, `structs.stat_rollup_metric` | tables | `pg_cron` `stat_rollup_snapshot` at :02 hourly, from `grid` / `struct_attribute` current state | webapp stat series |
| `structs.planet_activity_player_drift` | table | `pg_cron` `planet_activity_player_reconciler` at 03:33 daily | operators |
| `permission_player_id_idx`, `permission_object_id_idx` | indexes | — | `view.permission_*` |
| `planet_activity_time_idx` | **dropped** (prefix of `time_planet_seq_uidx`) | — | — |

`structs_indexer` has DML on `planet_activity_player` and
`planet_activity_player_drift`, `EXECUTE` on the backfill and reconcile
functions, and `SELECT` on everything else listed.

### 1.1 Why a trigger here, when the api_* rule is "no triggers"

`docs/guild-api-database-handoff.md` makes sync-state the only writer of
`structs.api_*` current-state tables and forbids triggers on them.
`planet_activity_player` is not current state: it is an index-like
derivative of an append-only event log, a pure function of the
`planet_activity` row plus ownership at that instant. Computing it in the
same statement that writes the row is what makes "ownership as of the event"
possible at all; sync-state would otherwise have to duplicate the
attribution rules in Go and run the same lookups. The specification lives in
one SQL function so both the trigger and the nightly reconciler use it.

## 2. Effect on the insert path

- `buffers.flushPlanetActivity` uses `pgx.CopyFrom`. `COPY FROM` fires row
  triggers, so attribution happens inside your flush. Measured on
  production: 500 rows, 13 ms without the trigger, 59 ms with it — about
  0.09 ms per `planet_activity` row, in the same transaction. At the current
  30–60k rows/day that is a few seconds of trigger time per day.
- The trigger runs `structs.planet_activity_players()` which reads
  `structs.player_object` (and `struct`/`fleet`/`planet` as fallback) for the
  ids in the event. Because it runs *inside your block transaction*, it sees
  the ownership state your own handlers have written earlier in the block.
  If a handler ordering places an ownership write *after* the activity
  write within the same block, attribution uses the pre-block owner. The
  nightly reconciler evaluates the same function with post-block ownership
  and would log one `extra` (old owner) and one `missing` (new owner) for
  that row. Ownership changes are rare in this game, so this should be
  near zero; if `missing` rows cluster on one category, that is the signal
  to reorder the handlers for it.
- `planet_activity_notify` (the `grass` pg_notify trigger) is unchanged and
  still fires after attribution.

## 3. Guardrails in sync-state tooling

1. **`readmodel.ValidateSchema`**: it currently checks the `api_*`
   projection tables. If you extend it, add
   `planet_activity_player` (table) — sync-state does not need the caggs or
   `stat_rollup` to run, so leave those out.
2. **`rewind` / any height-based delete**: there is no foreign key between
   the two hypertables. If a repair path deletes `planet_activity` rows
   (`WHERE block_height > H` or a `(time, planet_id, seq)` set), delete the
   same keys from `planet_activity_player` in the same transaction:

   ```sql
   DELETE FROM structs.planet_activity_player p
    WHERE p.block_height > $1;
   -- or, keyed:
   DELETE FROM structs.planet_activity_player p
    USING deleted d
    WHERE p.time = d.time AND p.planet_id = d.planet_id AND p.seq = d.seq;
   ```

   Rows you re-insert afterwards are attributed again by the trigger with
   ownership as it is *then*. If you forget the delete, nothing breaks: the
   nightly reconciler logs the leftovers as `state = 'orphan'` and you can
   remove them with the keyed delete above.
3. **`doctor`**: consider adding two checks alongside the `droppedTriggers`
   list — trigger `planet_activity_attribute` on `structs.planet_activity`
   must be **enabled** (`tgenabled <> 'D'`), and
   `max(time) FROM structs.planet_activity_player` should be within a few
   minutes of `max(time) FROM structs.planet_activity` while blocks flow.
   Both are cheap and catch the only two ways this can silently stop.

Nothing else: no `bootstrap.sql` change (the relations are created by
sqitch, and `bootstrap.sql` should not create or drop them), no handler
change, no new write in Go.

## 4. Reconciler and backfill (operators)

```sql
-- what the nightly run found (kept 90 days)
SELECT checked_at, state, category, count(*)
  FROM structs.planet_activity_player_drift
 GROUP BY 1, 2, 3 ORDER BY 1 DESC, 4 DESC;

-- run it by hand over a wider window, without logging
SELECT state, count(*) FROM structs.planet_activity_player_reconcile(FALSE, INTERVAL '7 days') GROUP BY 1;

-- repair a gap (idempotent; uses ownership as it is now)
SELECT structs.planet_activity_player_backfill('2026-09-10', '2026-09-11');
```

States: `missing` = the specification yields a row the side table lacks
(trigger disabled, or bulk load that bypassed it) — repair with the
backfill; `extra` = side table has a row the specification no longer
yields (ownership changed since the event) — expected, informational;
`orphan` = side row whose parent no longer exists — see §3.2.

The deploy backfilled all history (2.3M `planet_activity` rows → ~2.6M side
rows) one chunk per transaction at ~33k rows/s, and the verify asserts the
last 7 days are complete.

## 5. Docker / image items

Carried over from `docs/sync-state-ledger-identity-handoff.md` §7 (still
outstanding at the time of writing) plus two new ones:

- [docker-structs-guild] **`shm_size: 1g`** on the `structs-pg` service.
  Default 64 MB `/dev/shm` made a parallel hash join fail with
  `could not resize shared memory segment`. Every new function in this
  delivery runs with `max_parallel_workers_per_gather = 0` as a workaround;
  the reconcilers would be faster without it.
- [structs-pg image] **`pg_stat_statements`** in `shared_preload_libraries`
  (currently `timescaledb,pg_cron` in the `Dockerfile`).
  `extension-pg-stat-statements-20260914` creates the extension automatically
  once the library is loaded. This review, like the last one, had to infer
  hot statements from sampling.
- [structs-pg image] **`track_functions = pl`** in `postgresql.conf`, so
  `api_work_refresh()`, `planet_activity_attribute()`, `stat_rollup_snapshot()`
  and the reconcilers report call counts and time in
  `pg_stat_user_functions`. Negligible overhead.
- [docker-structs-guild] **pgbouncer** in transaction mode in front of
  `structs-pg` for `structs_webapp`: ~1,110 new sessions/min, ~5 statements
  each, `SET NAMES` on every connect. `structs_webapp` has role-level
  `search_path`, `statement_timeout` and `idle_in_transaction_session_timeout`
  (all fine with transaction pooling; no `SET` in application code). Point
  only the webapp at it; sync-state should keep its direct connection (it
  relies on session state: advisory writer lock, `LISTEN`, long
  transactions).
- [structs-pg image / ops] `structs`, `structs_indexer`, `structs_webapp`
  are all `SUPERUSER`; grants in sqitch are documentation until at least
  `structs_webapp` is `NOSUPERUSER`.

## 6. Reminders from the previous handoff

- **§5.1 `api_work`**: sync-state is still maintaining `structs.api_work`
  with the dirty-tracking approach from the earlier draft; the reconciler
  logs `extra` rows for destroyed structs each night. Switch to calling
  `SELECT structs.api_work_refresh($height, $time)` once per block after
  your writes; it is a diff against `view.work_live` and is idempotent.
- **§1.1 handler errors**: `EventDelete.objectId` double-encoded JSON (106k
  warnings, structs never marked destroyed), `EventPlanetAttribute` NOT NULL
  violations, `EventStructType` schema mismatch, `EventGrid` empty object id.
  The destroyed-struct gap directly inflates `view.work_live` and therefore
  `api_work_refresh()` cost.

## 7. Verification after deploy

```sql
SELECT change FROM sqitch.changes WHERE change LIKE '%20260915%' ORDER BY committed_at;   -- 10 rows

SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'structs.planet_activity'::regclass;
-- planet_activity_attribute  O   (and planet_activity_notify)

SELECT (SELECT max(time) FROM structs.planet_activity) parent, (SELECT max(time) FROM structs.planet_activity_player) side;

SELECT view_name, materialized_only FROM timescaledb_information.continuous_aggregates WHERE view_schema = 'structs';
SELECT hypertable_name, proc_name, schedule_interval, last_run_status, next_start
  FROM timescaledb_information.jobs JOIN timescaledb_information.job_stats USING (job_id)
 WHERE hypertable_schema = 'structs';

SELECT jobname, schedule, active FROM cron.job
 WHERE jobname IN ('planet_activity_player_reconciler', 'stat_rollup_snapshot');

SELECT metric, object_type, max(bucket), count(*) FROM structs.stat_rollup GROUP BY 1, 2 ORDER BY 1, 2;
```
