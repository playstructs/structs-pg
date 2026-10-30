-- Deploy structs-pg:role-structs-webapp-20261030-catalog to pg
BEGIN;
-- Existing provider/agreement catalog and market routes are read-only.
GRANT SELECT ON structs.provider,structs.agreement TO structs_webapp;
COMMIT;
