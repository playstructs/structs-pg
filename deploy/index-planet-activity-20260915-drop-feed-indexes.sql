-- Deploy structs-pg:index-planet-activity-20260915-drop-feed-indexes to pg
--
-- PHASE 2. Merge this branch only after the webapp confirms that
-- planetActivityByPlayer() reads structs.planet_activity_player (see
-- docs/webapp-activity-stats-handoff.md §1). Until then these two indexes
-- are what keeps the read-time attribution query from being worse than it is.
--
--   planet_activity_block_time_planet_seq_idx  ~200 MB across chunks, 4 scans
--                                              per chunk: the ORDER BY of the
--                                              per-player feed
--   planet_activity_detail_gin                 partial on struct_attack, zero
--                                              scans since creation
--
-- Guard:
--   1. the attribution side table is live (a row within the last 10
--      minutes), which proves the trigger path the new feed depends on is
--      running;
--   2. when pg_stat_statements is installed, structs_webapp has issued
--      statements against structs.planet_activity_player, i.e. the webapp
--      cutover has actually happened. (Checked 2026-09-15: the webapp feed
--      is planet_activity_player JOIN planet_activity on the unique
--      (time, planet_id, seq) index; neither dropped index appears in its
--      plan.)
--
-- A fresh database has neither table populated and no webapp traffic, so
-- there is no feed for these indexes to protect. Refusing there blocks
-- every later change. That case deploys with a NOTICE. Still refused: the
-- raw activity table has rows while attribution is empty, attribution is
-- stale, or the webapp has never read planet_activity_player.

BEGIN;

    DO $$
    DECLARE
        v_latest TIMESTAMPTZ;
        v_calls  BIGINT;
    BEGIN
        SELECT max(time) INTO v_latest FROM structs.planet_activity_player;
        IF v_latest IS NULL THEN
            IF EXISTS (SELECT 1 FROM structs.planet_activity) THEN
                RAISE EXCEPTION 'structs.planet_activity_player is empty but structs.planet_activity has rows; refusing to drop the feed indexes';
            END IF;
            RAISE NOTICE 'drop feed indexes: planet_activity and planet_activity_player are empty; nothing to protect on a fresh database';
            RETURN;
        END IF;

        IF v_latest < now() - INTERVAL '10 minutes' THEN
            RAISE EXCEPTION 'structs.planet_activity_player is not live (latest row: %); refusing to drop the feed indexes', v_latest;
        END IF;

        IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') THEN
            SELECT COALESCE(SUM(s.calls), 0) INTO v_calls
              FROM pg_stat_statements s
              JOIN pg_roles r ON r.oid = s.userid
             WHERE r.rolname = 'structs_webapp'
               AND s.query ILIKE '%planet_activity_player%';
            IF v_calls = 0 THEN
                RAISE EXCEPTION 'structs_webapp has never queried structs.planet_activity_player; the feed is still on the raw table, refusing to drop its indexes';
            END IF;
            RAISE NOTICE 'drop feed indexes: structs_webapp has % statement calls against planet_activity_player', v_calls;
        END IF;
    END
    $$;

    DROP INDEX IF EXISTS structs.planet_activity_block_time_planet_seq_idx;
    DROP INDEX IF EXISTS structs.planet_activity_detail_gin;

COMMIT;
