-- Revert structs-pg:role-structs-webapp-20261029-ledger from pg
BEGIN;
REVOKE SELECT ON structs.ledger FROM structs_webapp;
COMMIT;
