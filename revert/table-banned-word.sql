-- Revert structs-pg:table-banned-word from pg

BEGIN;

DROP TABLE IF EXISTS structs.banned_word CASCADE;

COMMIT;
