-- Revert structs-pg:table-guild from pg

BEGIN;

DROP TABLE structs.guild;

COMMIT;
