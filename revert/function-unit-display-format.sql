-- Revert structs-pg:function-unit-display-format from pg

BEGIN;

DROP FUNCTION structs.UNIT_DISPLAY_FORAMT();

COMMIT;
