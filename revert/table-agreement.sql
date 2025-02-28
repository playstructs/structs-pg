-- Revert structs-pg:table-agreement from pg

BEGIN;

DROP TABLE structs.agreement;

COMMIT;
