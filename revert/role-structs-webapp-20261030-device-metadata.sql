-- Revert structs-pg:role-structs-webapp-20261030-device-metadata from pg
BEGIN;
REVOKE SELECT,INSERT,UPDATE ON structs.player_address_meta FROM structs_webapp;
REVOKE SELECT ON structs.player_address_activity,view.address_inventory FROM structs_webapp;
COMMIT;
