-- Deploy structs-pg:table-stat-20260522-add-block-height to pg
--
-- Every grid / struct_attribute INSERT now carries bctx.Height on the
-- sync-state side. Adding block_height to all ten stat_* hypertables
-- lets us preserve that value instead of discarding it.
--
-- Nullable, no default → cheap ALTER on populated TimescaleDB
-- hypertables. Historical rows are backfilled by sync-state's operator
-- script (retire-cache.sql step 3).

BEGIN;

    ALTER TABLE structs.stat_ore                  ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_fuel                 ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_capacity             ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_load                 ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_structs_load         ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_power                ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_connection_capacity  ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_connection_count     ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_struct_health        ADD COLUMN IF NOT EXISTS block_height BIGINT;
    ALTER TABLE structs.stat_struct_status        ADD COLUMN IF NOT EXISTS block_height BIGINT;

COMMIT;
