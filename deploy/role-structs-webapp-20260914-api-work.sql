-- Deploy structs-pg:role-structs-webapp-20260914-api-work to pg

BEGIN;

    GRANT SELECT
        ON structs.api_work
        TO structs_webapp;

COMMIT;
