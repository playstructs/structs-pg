-- Revert structs-pg:table-banned-word from pg

BEGIN;

DROP TABLE structs.banned_word;

COMMIT;
