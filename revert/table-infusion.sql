-- Revert structs-pg:table-infusion from pg

BEGIN;

DROP TABLE IF EXISTS structs.infusion CASCADE;

COMMIT;
