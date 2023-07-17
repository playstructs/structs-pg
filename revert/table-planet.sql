-- Revert structs-pg:table-planet from pg

BEGIN;

DROP TABLE structs.planet;

COMMIT;
