-- Revert structs-pg:schema-signer from pg

BEGIN;

DROP SCHEMA signer;

COMMIT;
