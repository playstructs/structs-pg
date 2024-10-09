-- Revert structs-pg:table-ledger from pg

BEGIN;

DROP TABLE structs.ledger;

COMMIT;
