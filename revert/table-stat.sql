-- Revert structs-pg:table-stat from pg

BEGIN;

DROP TABLE structs.stat;

COMMIT;
