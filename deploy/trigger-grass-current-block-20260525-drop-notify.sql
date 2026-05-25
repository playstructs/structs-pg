-- Deploy structs-pg:trigger-grass-current-block-20260525-drop-notify to pg
--
-- sync-state now owns structs.current_block updates; block height is no
-- longer propagated to clients via pg_notify('grass', category=block).

BEGIN;

    DROP TRIGGER IF EXISTS CURRENT_BLOCK_NOTIFY ON structs.current_block;
    DROP FUNCTION IF EXISTS structs.CURRENT_BLOCK_NOTIFY();

COMMIT;
