-- Verify structs-pg:extension-pg-stat-statements-20260914 on pg

BEGIN;

    DO $$
    BEGIN
        IF 'pg_stat_statements' = ANY (
            string_to_array(replace(current_setting('shared_preload_libraries'), ' ', ''), ',')
        ) AND NOT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
        ) THEN
            RAISE EXCEPTION 'pg_stat_statements is preloaded but the extension is not created';
        END IF;
    END
    $$;

ROLLBACK;
