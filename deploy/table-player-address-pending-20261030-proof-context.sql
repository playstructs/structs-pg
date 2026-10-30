-- Deploy structs-pg:table-player-address-pending-20261030-proof-context to pg
BEGIN;
SET LOCAL lock_timeout = '5s';

-- NULL context preserves legacy inserts until the updated proof verifier writes
-- a complete context. Such a row must be re-signed before post-upgrade submission.
ALTER TABLE structs.player_address_pending
    ADD COLUMN player_id CHARACTER VARYING,
    ADD COLUMN guild_id CHARACTER VARYING,
    ADD COLUMN proof_chain_id CHARACTER VARYING,
    ADD COLUMN proof_protocol CHARACTER VARYING,
    ADD COLUMN proof_nonce NUMERIC,
    ADD COLUMN proof_height NUMERIC,
    ADD COLUMN proof_timeout_height NUMERIC,
    ADD CONSTRAINT player_address_pending_proof_context CHECK (
        (player_id IS NULL AND guild_id IS NULL AND proof_chain_id IS NULL
            AND proof_protocol IS NULL AND proof_nonce IS NULL AND proof_height IS NULL
            AND proof_timeout_height IS NULL)
        OR
        (player_id IS NOT NULL AND player_id ~ '^1-[1-9][0-9]*$'
            AND guild_id IS NOT NULL AND guild_id ~ '^0-[1-9][0-9]*$'
            AND proof_chain_id IS NOT NULL AND proof_chain_id <> ''
            AND proof_protocol IS NOT NULL
            AND proof_height IS NOT NULL AND proof_height BETWEEN 1 AND 9007199254740991
            AND proof_height = trunc(proof_height)
            AND proof_timeout_height IS NOT NULL
            AND proof_timeout_height = trunc(proof_timeout_height)
            AND (
                (proof_protocol = 'v0.21.0' AND proof_nonce IS NULL
                    AND proof_timeout_height BETWEEN proof_height AND 9007199254740991)
                OR
                (proof_protocol = 'v0.22.0' AND proof_nonce IS NOT NULL
                    AND proof_nonce = trunc(proof_nonce)
                    AND proof_nonce BETWEEN 0 AND 18446744073709551615 AND proof_timeout_height = 0)
            ))
    );

GRANT SELECT,INSERT,UPDATE ON structs.player_address_pending TO structs_webapp;
GRANT SELECT,INSERT,DELETE ON structs.player_address_activation_code TO structs_webapp;
-- SELECT ... FOR UPDATE needs UPDATE privilege on at least one column.
GRANT UPDATE (code) ON structs.player_address_activation_code TO structs_webapp;
COMMIT;
