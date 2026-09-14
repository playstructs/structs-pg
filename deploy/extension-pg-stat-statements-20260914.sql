-- Deploy structs-pg:extension-pg-stat-statements-20260914 to pg
--
-- Per-statement execution statistics. The extension only works when the
-- library is in shared_preload_libraries, which is set in the container
-- image's postgresql.conf (currently 'timescaledb,pg_cron') and needs a
-- restart. This change creates the extension when the library is loaded and
-- is a no-op otherwise, so the plan deploys cleanly on hosts that have not
-- picked up the image change yet; re-deploying after the restart is not
-- needed because the verify script is conditional as well, but the extension
-- can then be created by hand with the same statement.

BEGIN;

    DO $$
    BEGIN
        IF 'pg_stat_statements' = ANY (
            string_to_array(replace(current_setting('shared_preload_libraries'), ' ', ''), ',')
        ) THEN
            CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
        ELSE
            RAISE NOTICE 'pg_stat_statements is not in shared_preload_libraries; skipping CREATE EXTENSION';
        END IF;
    END
    $$;

COMMIT;
