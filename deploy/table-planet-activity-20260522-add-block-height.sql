-- Deploy structs-pg:table-planet-activity-20260522-add-block-height to pg
--
-- block_height makes per-block replay and "what happened in block N"
-- queries trivial without a join through sync_state.block_log on
-- (chain_id, block_time). sync-state populates this column on every
-- planet_activity INSERT going forward; historical rows are backfilled
-- by sync-state's operator script (retire-cache.sql step 3).

BEGIN;

    ALTER TABLE structs.planet_activity
        ADD COLUMN IF NOT EXISTS block_height BIGINT;

COMMIT;
