-- Revert structs-pg:table-player-address-pending-20261030-proof-context from pg
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE structs.player_address_pending IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.player_address_pending WHERE proof_protocol IS NOT NULL) THEN
        RAISE EXCEPTION 'pending registration proof context exists; retain the additive schema or restore a verified checkpoint';
    END IF;
END $$;
REVOKE UPDATE (code) ON structs.player_address_activation_code FROM structs_webapp;
REVOKE SELECT,INSERT,DELETE ON structs.player_address_activation_code FROM structs_webapp;
REVOKE SELECT,INSERT,UPDATE ON structs.player_address_pending FROM structs_webapp;
ALTER TABLE structs.player_address_pending
    DROP CONSTRAINT player_address_pending_proof_context,
    DROP COLUMN player_id,
    DROP COLUMN guild_id,
    DROP COLUMN proof_chain_id,
    DROP COLUMN proof_protocol,
    DROP COLUMN proof_nonce,
    DROP COLUMN proof_height,
    DROP COLUMN proof_timeout_height;
COMMIT;
