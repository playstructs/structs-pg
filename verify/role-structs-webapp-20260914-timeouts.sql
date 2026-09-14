-- Verify structs-pg:role-structs-webapp-20260914-timeouts on pg

BEGIN;

    DO $$
    DECLARE
        settings text[];
    BEGIN
        SELECT setconfig INTO settings
          FROM pg_db_role_setting
         WHERE setrole = 'structs_webapp'::regrole
           AND setdatabase = 0;

        IF settings IS NULL
           OR NOT ('statement_timeout=60s' = ANY (settings))
           OR NOT ('idle_in_transaction_session_timeout=5min' = ANY (settings)) THEN
            RAISE EXCEPTION 'structs_webapp role timeouts not set, found %', settings;
        END IF;
    END
    $$;

ROLLBACK;
