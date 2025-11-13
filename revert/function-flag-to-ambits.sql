-- Revert structs-pg:function-flag-to-ambits from pg

BEGIN;

DROP FUNCTION IF EXISTS structs.flag_to_ambits(INTEGER);

COMMIT;
