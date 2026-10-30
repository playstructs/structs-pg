-- Revert structs-pg:role-structs-webapp-20261030-catalog from pg
BEGIN;
REVOKE SELECT ON structs.provider,structs.agreement FROM structs_webapp;
COMMIT;
