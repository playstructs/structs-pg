-- Revert structs-pg:table-stat-rollup-20260915-hourly from pg

BEGIN;

    SELECT cron.unschedule('stat_rollup_snapshot');

    DROP FUNCTION IF EXISTS structs.stat_rollup_backfill(TEXT, TIMESTAMPTZ, TIMESTAMPTZ);
    DROP FUNCTION IF EXISTS structs.stat_rollup_snapshot(TIMESTAMPTZ);

    DROP TABLE IF EXISTS structs.stat_rollup;
    DROP TABLE IF EXISTS structs.stat_rollup_metric;

COMMIT;
