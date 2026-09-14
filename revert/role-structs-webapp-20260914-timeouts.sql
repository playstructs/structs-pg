-- Revert structs-pg:role-structs-webapp-20260914-timeouts from pg

BEGIN;

    ALTER ROLE structs_webapp RESET statement_timeout;
    ALTER ROLE structs_webapp RESET idle_in_transaction_session_timeout;

COMMIT;
