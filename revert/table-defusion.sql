-- Revert structs-pg:table-defusion from pg

BEGIN;

DROP TABLE IF EXISTS structs.defusion CASCADE;
DROP PROCEDURE IF EXISTS structs.CLEAN_DEFUSION();
SELECT cron.unschedule('defusion_cleaner');

COMMIT;
