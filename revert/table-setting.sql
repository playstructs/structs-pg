-- Revert structs-pg:table-setting from pg

BEGIN;

DROP TABLE IF EXISTS structs.setting CASCADE;

COMMIT;
