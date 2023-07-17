-- Revert structs-pg:table-substation from pg

BEGIN;

DROP TABLE structs.substation;

COMMIT;
