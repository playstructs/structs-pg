-- Verify structs-pg:config-database-20260914-observability on pg

BEGIN;

    DO $$
    DECLARE
        settings text[];
    BEGIN
        SELECT setconfig INTO settings
          FROM pg_db_role_setting
         WHERE setdatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
           AND setrole = 0;

        IF settings IS NULL
           OR NOT ('track_io_timing=on' = ANY (settings))
           OR NOT ('log_temp_files=0' = ANY (settings))
           OR NOT ('log_min_duration_statement=1s' = ANY (settings)) THEN
            RAISE EXCEPTION 'database observability settings not applied, found %', settings;
        END IF;
    END
    $$;

ROLLBACK;
