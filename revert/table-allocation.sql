-- Revert structs-pg:table-allocation from pg

BEGIN;

DROP TABLE structs.allocation;

COMMIT;
