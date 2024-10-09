-- Revert structs-pg:table-fleet from pg

BEGIN;

DROP TABLE structs.fleet;

COMMIT;
