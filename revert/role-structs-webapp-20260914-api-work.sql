-- Revert structs-pg:role-structs-webapp-20260914-api-work from pg

BEGIN;

    REVOKE SELECT
        ON structs.api_work
        FROM structs_webapp;

COMMIT;
