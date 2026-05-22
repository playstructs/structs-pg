-- Deploy structs-pg:table-current-block-20260522-add-sync-state-columns to pg
--
-- sync-state writes status/lag_blocks/tip_height on every commit so the
-- webapp can show "behind tip by N blocks" without round-tripping to RPC.
-- Previously added at runtime by sync-state's Bootstrap(); this change
-- moves ownership of the columns into sqitch so Phase C can remove the
-- runtime ALTERs.
--
-- IF NOT EXISTS for idempotency against environments where sync-state's
-- runtime Bootstrap() already added the columns.

BEGIN;

    ALTER TABLE structs.current_block
        ADD COLUMN IF NOT EXISTS status      TEXT,
        ADD COLUMN IF NOT EXISTS lag_blocks  BIGINT,
        ADD COLUMN IF NOT EXISTS tip_height  BIGINT;

COMMIT;
