-- Revert structs-pg:table-planet from pg

BEGIN;

DROP TABLE structs.planet;

DROP TABLE structs.planet_attribute;
DROP TABLE structs.planet_meta;

COMMIT;
