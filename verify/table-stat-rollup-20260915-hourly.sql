-- Verify structs-pg:table-stat-rollup-20260915-hourly on pg
--
-- Structure, registry, cron, backfilled history present for every metric,
-- and a rolled-back snapshot whose ore/planet total equals current grid state.

BEGIN;

    SELECT bucket, metric, object_type, sum, population, samples, source FROM structs.stat_rollup WHERE FALSE;

    DO $$
    DECLARE
        v_metrics   INT;
        v_missing   TEXT;
        v_snapshot  NUMERIC;
        v_grid      NUMERIC;
        v_bucket    TIMESTAMPTZ := date_trunc('hour', now()) + INTERVAL '100 years'; -- never collides
    BEGIN
        SELECT count(*) INTO v_metrics FROM structs.stat_rollup_metric;
        IF v_metrics <> 10 THEN
            RAISE EXCEPTION 'expected 10 stat_rollup_metric rows, found %', v_metrics;
        END IF;

        IF to_regprocedure('structs.stat_rollup_snapshot(timestamptz)') IS NULL
           OR to_regprocedure('structs.stat_rollup_backfill(text, timestamptz, timestamptz)') IS NULL THEN
            RAISE EXCEPTION 'expected stat_rollup_snapshot and stat_rollup_backfill functions';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'stat_rollup_snapshot') THEN
            RAISE EXCEPTION 'stat_rollup_snapshot cron job is not scheduled';
        END IF;

        -- every metric whose sample table has data has backfilled history
        SELECT string_agg(m.metric, ', ') INTO v_missing
          FROM structs.stat_rollup_metric m
         WHERE NOT EXISTS (SELECT 1 FROM structs.stat_rollup r WHERE r.metric = m.metric AND r.source = 'backfill')
           AND m.metric IN ('ore', 'struct_health', 'struct_status', 'structs_load');
        IF v_missing IS NOT NULL THEN
            RAISE EXCEPTION 'no backfilled stat_rollup rows for: %', v_missing;
        END IF;

        PERFORM structs.stat_rollup_snapshot(v_bucket);

        SELECT r.sum INTO v_snapshot
          FROM structs.stat_rollup r
         WHERE r.metric = 'ore' AND r.object_type = 'planet' AND r.bucket = v_bucket;

        SELECT COALESCE(sum(g.val), 0) INTO v_grid
          FROM structs.grid g
         WHERE g.attribute_type = 'ore' AND g.object_type = 'planet';

        IF v_snapshot IS DISTINCT FROM v_grid THEN
            RAISE EXCEPTION 'stat_rollup_snapshot ore/planet = %, grid says %', v_snapshot, v_grid;
        END IF;
    END
    $$;

ROLLBACK;
