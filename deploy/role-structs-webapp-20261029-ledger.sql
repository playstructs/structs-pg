-- Deploy structs-pg:role-structs-webapp-20261029-ledger to pg
BEGIN;
-- Existing history and confirmed-source reads use the same ledger. No writes
-- or broad schema grants are needed by the webapp.
GRANT SELECT ON structs.ledger TO structs_webapp;
COMMIT;
