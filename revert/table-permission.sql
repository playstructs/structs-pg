-- Revert structs-pg:table-permission from pg

BEGIN;

DROP TABLE structs.permission;

COMMIT;
