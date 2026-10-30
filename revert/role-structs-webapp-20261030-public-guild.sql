-- Revert structs-pg:role-structs-webapp-20261030-public-guild from pg
BEGIN;
REVOKE SELECT ON view.player,view.reactor FROM structs_webapp;
COMMIT;
