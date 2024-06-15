-- Revert structs-pg:table-signer-account from pg

BEGIN;

DROP TABLE signer.account;

COMMIT;
