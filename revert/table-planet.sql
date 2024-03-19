-- Revert structs-pg:table-planet from pg

BEGIN;

DROP TABLE structs.planet;

DROP TABLE structs.grid_meta;

COMMIT;
