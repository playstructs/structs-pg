-- Deploy structs-pg:table-player-address-pending-20251229-add-permissions to pg

BEGIN;

    ALTER TABLE structs.player_address_pending ADD COLUMN permissions INTEGER;

COMMIT;
