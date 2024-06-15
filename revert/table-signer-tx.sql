-- Revert structs-pg:table-signer-tx from pg

BEGIN;

DROP TABLE signer.tx;

COMMIT;
