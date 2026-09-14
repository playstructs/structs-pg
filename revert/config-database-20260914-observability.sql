-- Revert structs-pg:config-database-20260914-observability from pg

BEGIN;

    DO $$
    BEGIN
        EXECUTE format('ALTER DATABASE %I RESET track_io_timing', current_database());
        EXECUTE format('ALTER DATABASE %I RESET log_temp_files', current_database());
        EXECUTE format('ALTER DATABASE %I RESET log_min_duration_statement', current_database());
    END
    $$;

COMMIT;
