-- Revert structs-pg:trigger-grass-current-block from pg

BEGIN;

DROP TRIGGER IF EXISTS CURRENT_BLOCK_NOTIFY ON structs.current_block;
DROP FUNCTION IF EXISTS structs.CURRENT_BLOCK_NOTIFY();

COMMIT;
