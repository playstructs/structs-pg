-- Revert structs-pg:table-signer-role from pg

BEGIN;

DROP TABLE signer.role;

COMMIT;
