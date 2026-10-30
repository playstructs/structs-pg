-- Deploy structs-pg:table-signer-tx-20261030-build-cancel-type to pg
-- Commit the enum literal before compiling/using gameplay wrapper bodies.
BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TYPE structs.signer_tx_type ADD VALUE IF NOT EXISTS 'struct-build-cancel';
COMMIT;
