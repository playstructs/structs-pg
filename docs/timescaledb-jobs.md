# TimescaleDB policy scheduler workaround

`timescaledb-jobs-20261117-portal-workaround` moves the three activity refresh
policies, planet activity compression, and Timescale job-history retention to
pg_cron. PostgreSQL 18.7's portal validation exposes a Timescale background runner
bug: `cannot drop portal "" while it is being set up` (SQLSTATE 24000).
See [upstream issue 11038](https://github.com/timescale/timescaledb/issues/11038).
Both Timescale 2.31.0 and 2.32.0 are reported affected. The job can commit work
before reporting failure, so Failed status alone does not establish missing data.

## Deploy

Use the normal superuser migration connection, with TimescaleDB and pg_cron
loaded. The migration is in `sqitch.plan`; new deployments receive it through
normal `sqitch deploy`. For an explicit target:

```sh
sqitch deploy "$SQITCH_TARGET" --to timescaledb-jobs-20261117-portal-workaround
sqitch verify "$SQITCH_TARGET" --from timescaledb-jobs-20261117-portal-workaround --to timescaledb-jobs-20261117-portal-workaround
```

`SQITCH_TARGET` is your configured Sqitch target or database URI. The deploy is
transactional and requires an idle native policy runner; retry if it reports a
running job. No database restart or extension upgrade is needed.

Policy IDs and the Timescale extension schema are discovered, not hard-coded.
The migration retains policy owners, configuration and original scheduled flags
in `structs.timescale_portal_workaround`. Unrelated jobs are untouched. Policies
that were intentionally disabled remain disabled. Matching incident workaround
cron jobs are adopted; conflicting names/settings and custom policy intervals
fail atomically rather than being overwritten.

Schedules use pg_cron's configured timezone (UTC in the local deployment):

| Policy | Schedule |
| --- | --- |
| Hourly activity | Every 10 minutes |
| Daily planet activity | Minute 3 every hour |
| Daily player activity | Minute 5 every hour |
| Planet activity compression | 00:15 and 12:15 |
| Timescale job-history retention | 00:20, 06:20, 12:20, 18:20 |

Each command is a top-level `CALL <extension_schema>.run_job(<discovered_id>)`.
Native scheduling is disabled for these policies. pg_cron serializes each named
job's executions. Avoid manually running the same policy while its cron job runs.
Hourly/daily schedules are staggered; if hourly refresh takes over three minutes,
check that the next daily run incorporates its newly materialized hours.
This is a scheduler workaround, not an upstream binary fix. It applies on all
versions until deliberately retired; no speculative version gate is used.

## Verify execution and catch-up

Sqitch verification checks scheduler configuration without running jobs or
modifying data. Execution history belongs to pg_cron: foreground `run_job` does
**not** refresh Timescale's native `job_stats` failure/success counters.

```sql
SELECT c.jobname, c.schedule, c.username, c.active,
       r.status, r.start_time, r.end_time-r.start_time AS duration, r.return_message
FROM structs.timescale_portal_workaround s
JOIN cron.job c ON c.jobid=s.cron_job_id
LEFT JOIN LATERAL (
  SELECT * FROM cron.job_run_details r
  WHERE r.jobid=c.jobid ORDER BY runid DESC LIMIT 1
) r ON true
ORDER BY c.jobname;

SELECT count(*) AS overdue_compression_chunks
FROM timescaledb_information.chunks
WHERE hypertable_schema='structs' AND hypertable_name='planet_activity'
  AND NOT is_compressed AND range_end < now()-interval '30 days';

SELECT count(*) AS expired_job_history
FROM _timescaledb_internal.bgw_job_stat_history
WHERE execution_finish < now()-interval '1 month';
```

For immediate validation, temporarily quiesce these cron jobs with
`cron.alter_job(cron_job_id, active => false)`, wait for active runs to finish,
then run each recorded `cron_command` separately through psql in autocommit mode
(hourly first, then daily). Do not put `CALL run_job` inside a transaction or DO
block. Reenable the cron jobs afterward and observe successful scheduled runs.

Compare aggregate groups against source events over complete eligible buckets:

- Hourly: `planet_activity`, grouped by `time_bucket('1 hour', time)`, category,
  planet_id. Use whole hours inside the three-day lookback and before
  `date_trunc('hour', now()-interval '10 minutes')`.
- Daily: same source grouped by day, category, planet_id. Use completed days in
  the seven-day lookback; compare after hourly refresh finishes.
- Player daily: `planet_activity_player`, grouped by day, player_id, category,
  role, over completed days in the seven-day lookback.

Discover backing tables via `timescaledb_information.continuous_aggregates` and
compare against their rows directly, so real-time views do not mask unrefreshed
materialization. Use bidirectional EXCEPT to detect missing, extra or differing
groups. An unfinished hour/day is intentionally not materialized. For an outage
longer than the configured lookback, explicitly refresh the uncovered range
with `refresh_continuous_aggregate`, hourly before daily.

## Rollback / retire after an upstream fix

First test a fixed Timescale build's native job runner on an isolated database.
An upgrade to 2.32.0 alone is not a demonstrated fix. Reverting on an affected
server restores the failing runner for policies originally scheduled natively.

Quiesce cron in a separate committed session before reverting:

```sql
SELECT cron.alter_job(cron_job_id, active => false)
FROM structs.timescale_portal_workaround WHERE cron_job_id IS NOT NULL;

SELECT r.jobid, r.status
FROM cron.job_run_details r
JOIN structs.timescale_portal_workaround s ON s.cron_job_id=r.jobid
WHERE r.status IN ('starting','running');
```

Wait until the second query is empty. Revert **to the preceding change**, not to
this change (Sqitch's target remains deployed):

```sh
sqitch revert "$SQITCH_TARGET" --to influence-contest-20261117
```

Review later deployed changes first: Sqitch will also revert changes after this
migration. The revert rejects active runs or unexpected cron identity/command
changes. It removes only cron jobs created by the migration, restores original
native scheduled flags, and drops the snapshot table. Policy IDs, configuration,
materialized data and compression are retained.

For a host that already had the incident workaround, rollback restores that
pre-migration workaround, including its active cron schedules. To retire such
an adopted workaround after the upstream fix, quiesce its cron jobs again,
explicitly unschedule them, and reenable the corresponding native policies with
`alter_job(..., scheduled => true, next_start => now())`. Do not leave both
schedulers enabled. If rollback fails after quiescing, resolve the reported
conflict or reenable the recorded cron jobs to resume maintenance.

## Integration test

Create a disposable container from the structs-pg image with no production
volumes or network. The image must contain Timescale 2.31.0 and an empty `structs`
database. Never point the test at the running application container.

```sh
docker run -d --name structs-pg-timescale-migration-test --network none \
  -e POSTGRES_MEMORY_MB=512 --memory=1g "$STRUCTS_PG_IMAGE"
# Wait for PostgreSQL readiness.
TIMESCALE_TEST_CONTAINER=structs-pg-timescale-migration-test \
  python3 tests/test_timescale_portal_workaround.py
docker rm -f structs-pg-timescale-migration-test
```

The test uses real hypertables/policies with shifted IDs, executes all five jobs
through pg_cron, verifies fresh deploy/revert, incident-workaround adoption,
intentionally disabled policies, and atomic failure on conflicting cron jobs.
