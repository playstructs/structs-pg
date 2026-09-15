-- Deploy structs-pg:compression-planet-activity-20260915 to pg
--
-- PHASE 2. Compress structs.planet_activity chunks older than 30 days.
--
-- planet_activity is ~900 MB of append-only history (25 weekly chunks, 20 of
-- them older than 30 days) that is read almost exclusively through the
-- newest chunks. Every remaining read path is keyed by planet_id and ordered
-- by time/seq, so:
--
--   segmentby planet_id           per-planet pages decompress one segment
--   orderby   time DESC, seq DESC matches the unique (time, planet_id, seq)
--                                 index and the feed order, which is what
--                                 lets Timescale keep the unique constraint
--                                 on compressed chunks
--
-- Inserts only ever land in the current chunk (rows are written at block
-- time), so the compressed chunks see no writes. The attribution trigger
-- and the grass notify trigger are unaffected.
--
-- The policy compresses in the background; nothing is compressed inline by
-- this deploy, so it is quick. Measured 7.1x on a real chunk (35 MB -> 5 MB,
-- rolled-back compress_chunk on 2026-09-15).
--
-- Guard. The webapp feed joins planet_activity_player to planet_activity on
-- (time, planet_id, seq). With a plain JOIN the planner probes every chunk
-- for every row and, on a compressed chunk, switches to decompressing the
-- whole chunk for deep pages (147 ms -> 1,000 ms measured). With the
-- LATERAL form (docs/webapp-activity-stats-handoff.md §1.2) Timescale
-- excludes chunks at runtime and pages are flat at 6-9 ms compressed or
-- not. Re-measured 2026-09-15 20:40 with the webapp's deployed LATERAL
-- query and its real page size (~1,800 rows/call, 37 us per row), two
-- chunks compressed and rolled back: a page whose rows land in a compressed
-- chunk 68 -> 104 ms, the whole 7,953-row history of the busiest player
-- 280 -> 342 ms, a 100-row page unchanged at ~11 ms, 24 chunks excluded at
-- runtime in every case. So: refuse on positive evidence that the old shape
-- is what this host's webapp runs, i.e. pg_stat_statements (counters since
-- server start) shows the plain JOIN and never the LATERAL form, or shows
-- both and the JOIN is still being called (20 s window). A host with no
-- webapp feed traffic at all since it started has nothing to protect and
-- must not block every later change in the plan; it deploys with a NOTICE.
-- Production (crew) deployed 2026-09-15 20:47 under the strict form of this
-- guard: LATERAL 53 calls, JOIN 378 and unchanged.

BEGIN;

    DO $$
    DECLARE
        v_lateral      BIGINT;
        v_join_before  BIGINT;
        v_join_after   BIGINT;
    BEGIN
            -- extension-pg-stat-statements-20260914 was a no-op on hosts whose
            -- image did not yet preload the library. It does now, so create
            -- the extension here if it is still missing; the counters have
            -- been accumulating in shared memory since the server started.
            IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') THEN
                IF 'pg_stat_statements' = ANY (
                    string_to_array(replace(current_setting('shared_preload_libraries'), ' ', ''), ',')
                ) THEN
                    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
                    RAISE NOTICE 'planet_activity compression: created pg_stat_statements (missing since extension-pg-stat-statements-20260914 ran before the library was preloaded)';
                ELSE
                    RAISE EXCEPTION 'planet_activity compression refused: pg_stat_statements is not in shared_preload_libraries, cannot verify the webapp feed shape';
                END IF;
            END IF;

        SELECT COALESCE(SUM(s.calls), 0) INTO v_lateral
          FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
         WHERE r.rolname = 'structs_webapp'
           AND s.query ILIKE '%planet_activity_player%'
           AND s.query ILIKE '%LATERAL%planet_activity a%';
        SELECT COALESCE(SUM(s.calls), 0) INTO v_join_before
          FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
         WHERE r.rolname = 'structs_webapp'
           AND s.query ILIKE '%FROM structs.planet_activity_player p JOIN structs.planet_activity a%';

        IF v_lateral = 0 AND v_join_before = 0 THEN
            RAISE NOTICE 'planet_activity compression: structs_webapp has issued no player feed query since this server started (neither shape); nothing to verify, proceeding';
            RETURN;
        END IF;

        IF v_lateral = 0 THEN
            RAISE EXCEPTION 'planet_activity compression refused: structs_webapp runs the plain JOIN feed query (% calls) and has never issued the LATERAL form (handoff §1.2); compressed chunks would be fully decompressed for deep feed pages', v_join_before;
        END IF;

        PERFORM pg_sleep(20);
        PERFORM pg_stat_clear_snapshot();
        SELECT COALESCE(SUM(s.calls), 0) INTO v_join_after
          FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
         WHERE r.rolname = 'structs_webapp'
           AND s.query ILIKE '%FROM structs.planet_activity_player p JOIN structs.planet_activity a%';
        IF v_join_after > v_join_before THEN
            RAISE EXCEPTION 'planet_activity compression refused: the plain JOIN feed query still ran % time(s) in the last 20 s', v_join_after - v_join_before;
        END IF;

        RAISE NOTICE 'planet_activity compression: LATERAL feed calls %, plain JOIN calls % (unchanged over 20 s)', v_lateral, v_join_after;
    END
    $$;

    ALTER TABLE structs.planet_activity SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'planet_id',
        timescaledb.compress_orderby   = 'time DESC, seq DESC'
    );

    SELECT add_compression_policy('structs.planet_activity', INTERVAL '30 days');

COMMIT;
