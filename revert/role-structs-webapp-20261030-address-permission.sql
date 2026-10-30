-- Revert structs-pg:role-structs-webapp-20261030-address-permission from pg
BEGIN;
REVOKE SELECT ON structs.permission FROM structs_webapp;
COMMIT;
