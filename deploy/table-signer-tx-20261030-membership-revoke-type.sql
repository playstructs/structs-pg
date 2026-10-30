-- Deploy structs-pg:table-signer-tx-20261030-membership-revoke-type to pg
-- Commit the enum literal before compiling/using membership wrapper bodies.
BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TYPE structs.signer_tx_type ADD VALUE IF NOT EXISTS 'guild-membership-invite-revoke';
COMMIT;
