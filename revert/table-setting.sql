-- Revert structs-pg:table-setting from pg

BEGIN;

DROP TABLE structs.setting;

COMMIT;
