-- Revert structs-pg:table-player-address-20261030-activation-instance from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE structs.player_address_activation_code,structs.player_address_pending IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS(SELECT 1 FROM structs.player_address_activation_code)
        OR EXISTS(SELECT 1 FROM structs.player_address_pending WHERE activation_id IS NOT NULL) THEN
        RAISE EXCEPTION 'issued device activation identities exist; retain the additive schema';
    END IF;
END $$;
ALTER TABLE structs.player_address_pending
    DROP CONSTRAINT player_address_pending_one_device,
    DROP CONSTRAINT player_address_pending_activation_instance,
    DROP COLUMN activation_id;
ALTER TABLE structs.player_address_activation_code
    DROP CONSTRAINT player_address_activation_instance,
    DROP COLUMN activation_id;
COMMIT;
