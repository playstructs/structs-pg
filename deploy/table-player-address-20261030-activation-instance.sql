-- Deploy structs-pg:table-player-address-20261030-activation-instance to pg
BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TABLE structs.player_address_activation_code
    ADD COLUMN activation_id UUID NOT NULL DEFAULT gen_random_uuid(),
    ADD CONSTRAINT player_address_activation_instance UNIQUE (activation_id);
ALTER TABLE structs.player_address_pending
    ADD COLUMN activation_id UUID,
    ADD CONSTRAINT player_address_pending_activation_instance
        FOREIGN KEY (activation_id) REFERENCES structs.player_address_activation_code(activation_id) ON DELETE CASCADE,
    ADD CONSTRAINT player_address_pending_one_device UNIQUE (activation_id);
COMMENT ON COLUMN structs.player_address_pending.activation_id IS
    'One consent per issued code instance. NULL is legacy and cannot authorize the v022 webapp flow.';
COMMIT;
