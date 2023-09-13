-- Revert structs-pg:table-infusion from pg

BEGIN;

DROP TABLE structs.infusion;

COMMIT;
