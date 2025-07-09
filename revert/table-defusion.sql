-- Revert structs-pg:table-defusion from pg

BEGIN;

DROP TABLE structs.defusion;

COMMIT;
