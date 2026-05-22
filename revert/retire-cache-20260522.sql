-- Revert structs-pg:retire-cache-20260522 from pg
--
-- DESTRUCTIVE: this revert removes the cache.* compatibility views.
-- The cache.* DATA cannot be restored from this script — the original
-- BIGSERIAL-keyed tables are gone and sync_state.raw_* does not preserve
-- the auto-generated rowid sequence. If you need the legacy cache.*
-- tables back (with data), restore the database from a PITR backup
-- taken before retire-cache-20260522 was deployed.
--
-- This revert also does NOT re-create the seven dropped triggers or
-- the two dropped structs.* trigger functions. To recover those,
-- continue reverting backwards past cache-trigger-add-queue-20260427-ugc-fields
-- → ... → cache-system; sqitch will re-run those deploy scripts and
-- restore the cache schema + trigger surface (without the original
-- row data).

BEGIN;

    DROP SCHEMA IF EXISTS cache CASCADE;

COMMIT;
