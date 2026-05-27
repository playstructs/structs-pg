-- Revert structs-pg:table-current-block-20260522-add-sync-state-columns from pg

BEGIN;

    ALTER TABLE structs.current_block
        DROP COLUMN IF EXISTS tip_height,
        DROP COLUMN IF EXISTS lag_blocks,
        DROP COLUMN IF EXISTS status;

COMMIT;
