-- Revert structs-pg:table-allocation from pg

BEGIN;

DROP TABLE IF EXISTS structs.allocation CASCADE;

COMMIT;
