-- Revert structs-pg:table-reactor from pg

BEGIN;

DROP TABLE structs.reactor; 

COMMIT;
