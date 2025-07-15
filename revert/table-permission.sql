-- Revert structs-pg:table-permission from pg

BEGIN;

DROP TABLE IF EXISTS structs.permission CASCADE;

COMMIT;
