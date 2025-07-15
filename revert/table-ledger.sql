-- Revert structs-pg:table-ledger from pg

BEGIN;

DROP TABLE IF EXISTS structs.ledger CASCADE;
DROP TYPE IF EXISTS structs.ledger_direction;
DROP TYPE IF EXISTS structs.ledger_action;

COMMIT;
