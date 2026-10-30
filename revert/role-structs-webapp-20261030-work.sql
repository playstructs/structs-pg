-- Revert structs-pg:role-structs-webapp-20261030-work from pg
BEGIN;
REVOKE SELECT ON view.work FROM structs_webapp;
COMMIT;
