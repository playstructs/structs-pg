-- Deploy structs-pg:role-structs-webapp-20261030-device-metadata to pg
BEGIN;
-- Existing private device screens read activity and retained-address inventory.
-- Only browser metadata is application-owned; chain projections stay read-only.
GRANT SELECT ON structs.player_address_activity,view.address_inventory TO structs_webapp;
GRANT SELECT,INSERT,UPDATE ON structs.player_address_meta TO structs_webapp;
COMMIT;
