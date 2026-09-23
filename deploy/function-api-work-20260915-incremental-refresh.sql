-- Deploy structs-pg:function-api-work-20260915-incremental-refresh to pg
--
-- Make structs.api_work_refresh() incremental.
--
-- Measured 2026-09-15, one hour of production: 680 blocks, 680 full
-- recomputes of view.work_live at ~166 ms each (three scans of struct's 290k
-- rows plus one of struct_attribute's 367k, to produce 4,176 rows), 64% of
-- all statement time on the server. Only 163 of those blocks changed anything
-- in api_work, and those changed ~2 rows each.
--
-- The work list is a pure function of a short list of inputs (the view
-- definition, confirmed by the game rules: build clocks are set once, mine/
-- refine clocks move after each job, raid clocks more often, and rows vanish
-- when the clock is cleared). So:
--
--   1. structs.api_work_dirty is a small queue of (kind, id) keys.
--   2. Row-level AFTER triggers on the six input tables enqueue a key when,
--      and only when, a column the view reads changes:
--
--        struct            owner, type, location_type, location_id,
--                          is_destroyed; insert; delete        -> struct
--        struct_attribute  status, blockStartBuild               -> struct
--        planet_attribute  blockStartOreMine, blockStartOreRefine,
--                          blockStartRaid, planetaryShield      -> planet
--        grid              ore, only when it crosses zero (the view asks
--                          ore > 0)                             -> planet | player
--        planet            location_list_start; insert; delete  -> planet
--        fleet             owner; insert; delete                -> fleet
--
--   3. api_work_refresh(height, time) -- same signature, sync-state does not
--      change -- drains the queue. Empty queue: stamp api_refresh_state and
--      return (76% of blocks). Otherwise expand planet/player/fleet keys to
--      the structs and planets they influence (max 11 structs on a planet,
--      27 per owner today), recompute just those rows through the unchanged
--      specification (view.work_live WHERE target_id = ANY(keys) is pushed
--      into every UNION ALL branch as primary-key lookups: 3 ms measured),
--      and diff them against api_work. More than 2,000 keys falls back to
--      the full pass.
--
--   4. The previous full pass survives as api_work_refresh_full(). pg_cron
--      runs it hourly as a resync; with p_log it writes every correction it
--      had to make into api_work_drift (state missing/extra/stale), so a
--      dependency this change missed shows up there as evidence instead of
--      as silent staleness. The nightly api_work_reconcile() is unchanged.
--
-- Both refresh paths take a transaction-scoped advisory lock so the hourly
-- full pass and sync-state's per-block call serialize instead of racing.
--
-- Triggers run as the writing role (structs_indexer), hence the grants on
-- the queue. Parallel workers stay disabled in the functions (64 MB /dev/shm).

BEGIN;

    ------------------------------------------------------------------------
    -- 1. dirty-key queue
    ------------------------------------------------------------------------

    CREATE TABLE structs.api_work_dirty (
        kind        TEXT        NOT NULL CHECK (kind IN ('struct', 'planet', 'player', 'fleet')),
        id          VARCHAR     NOT NULL,
        enqueued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        PRIMARY KEY (kind, id)
    );

    COMMENT ON TABLE structs.api_work_dirty IS
        'Keys whose work rows may have changed since the last api_work_refresh(); filled by triggers on struct, struct_attribute, planet_attribute, grid, planet, fleet; drained by api_work_refresh().';

    GRANT SELECT, INSERT, DELETE ON structs.api_work_dirty TO structs_indexer;

    -- Expanding a dirty planet to the structs on it is the one lookup the
    -- refresh needs that had no index (290k-row seq scan, 42 ms measured).
    CREATE INDEX struct_location_id_idx ON structs.struct (location_id);

    ------------------------------------------------------------------------
    -- 2. trigger function + triggers
    ------------------------------------------------------------------------

    CREATE OR REPLACE FUNCTION structs.api_work_mark_dirty()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS
    $BODY$
    DECLARE
        v_kind TEXT;
        v_ids  VARCHAR[];
    BEGIN
        CASE TG_TABLE_NAME
            WHEN 'struct' THEN
                v_kind := 'struct';
                v_ids  := ARRAY[COALESCE(NEW.id, OLD.id)];
            WHEN 'struct_attribute' THEN
                v_kind := 'struct';
                v_ids  := ARRAY_REMOVE(ARRAY[NEW.object_id, OLD.object_id], NULL);
            WHEN 'planet_attribute' THEN
                v_kind := 'planet';
                v_ids  := ARRAY_REMOVE(ARRAY[NEW.object_id, OLD.object_id], NULL);
            WHEN 'grid' THEN
                -- object_type is 'planet' (MINE eligibility) or 'player'
                -- (REFINE eligibility); anything else is not a work input.
                v_kind := COALESCE(NEW.object_type, OLD.object_type);
                IF v_kind NOT IN ('planet', 'player') THEN
                    RETURN NULL;
                END IF;
                v_ids  := ARRAY_REMOVE(ARRAY[NEW.object_id, OLD.object_id], NULL);
            WHEN 'planet' THEN
                v_kind := 'planet';
                v_ids  := ARRAY[COALESCE(NEW.id, OLD.id)];
            WHEN 'fleet' THEN
                v_kind := 'fleet';
                v_ids  := ARRAY[COALESCE(NEW.id, OLD.id)];
            ELSE
                RETURN NULL;
        END CASE;

        INSERT INTO structs.api_work_dirty (kind, id)
        SELECT DISTINCT v_kind, u FROM unnest(v_ids) AS u
        ON CONFLICT DO NOTHING;

        RETURN NULL;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_mark_dirty() IS
        'Row trigger: enqueue the struct/planet/player/fleet key whose work rows may have changed into structs.api_work_dirty.';

    -- struct: the columns the view reads
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.struct
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.struct
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.struct
        FOR EACH ROW
        WHEN ((OLD.owner, OLD.type, OLD.location_type, OLD.location_id, OLD.is_destroyed)
              IS DISTINCT FROM
              (NEW.owner, NEW.type, NEW.location_type, NEW.location_id, NEW.is_destroyed))
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    -- struct_attribute: status (all three struct categories), blockStartBuild
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.struct_attribute
        FOR EACH ROW
        WHEN (NEW.attribute_type IN ('status', 'blockStartBuild'))
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.struct_attribute
        FOR EACH ROW
        WHEN (OLD.attribute_type IN ('status', 'blockStartBuild'))
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.struct_attribute
        FOR EACH ROW
        WHEN ((NEW.attribute_type IN ('status', 'blockStartBuild') OR OLD.attribute_type IN ('status', 'blockStartBuild'))
              AND (OLD.val, OLD.object_id, OLD.attribute_type) IS DISTINCT FROM (NEW.val, NEW.object_id, NEW.attribute_type))
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    -- planet_attribute: the three clocks and the shield
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.planet_attribute
        FOR EACH ROW
        WHEN (NEW.attribute_type IN ('blockStartOreMine', 'blockStartOreRefine', 'blockStartRaid', 'planetaryShield'))
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.planet_attribute
        FOR EACH ROW
        WHEN (OLD.attribute_type IN ('blockStartOreMine', 'blockStartOreRefine', 'blockStartRaid', 'planetaryShield'))
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.planet_attribute
        FOR EACH ROW
        WHEN ((NEW.attribute_type IN ('blockStartOreMine', 'blockStartOreRefine', 'blockStartRaid', 'planetaryShield')
               OR OLD.attribute_type IN ('blockStartOreMine', 'blockStartOreRefine', 'blockStartRaid', 'planetaryShield'))
              AND (OLD.val, OLD.object_id, OLD.attribute_type) IS DISTINCT FROM (NEW.val, NEW.object_id, NEW.attribute_type))
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    -- grid: ore, only when eligibility (ore > 0) flips
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.grid
        FOR EACH ROW
        WHEN (NEW.attribute_type = 'ore' AND NEW.val > 0)
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.grid
        FOR EACH ROW
        WHEN (OLD.attribute_type = 'ore' AND OLD.val > 0)
        EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.grid
        FOR EACH ROW
        WHEN (NEW.attribute_type = 'ore'
              AND ((OLD.val > 0) IS DISTINCT FROM (NEW.val > 0) OR OLD.object_id IS DISTINCT FROM NEW.object_id))
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    -- planet: the raid pointer
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.planet
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.planet
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.planet
        FOR EACH ROW
        WHEN (OLD.location_list_start IS DISTINCT FROM NEW.location_list_start)
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    -- fleet: the raiding player
    CREATE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.fleet
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_del AFTER DELETE ON structs.fleet
        FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();
    CREATE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.fleet
        FOR EACH ROW
        WHEN (OLD.owner IS DISTINCT FROM NEW.owner)
        EXECUTE FUNCTION structs.api_work_mark_dirty();

    ------------------------------------------------------------------------
    -- 3. full pass (the previous api_work_refresh body), now also the resync
    ------------------------------------------------------------------------

    CREATE OR REPLACE FUNCTION structs.api_work_refresh_full(
        p_source_height BIGINT,
        p_source_time   TIMESTAMPTZ DEFAULT NOW(),
        p_log           BOOLEAN     DEFAULT FALSE
    )
    RETURNS TABLE (inserted BIGINT, updated BIGINT, deleted BIGINT)
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        v_inserted   BIGINT := 0;
        v_updated    BIGINT := 0;
        v_deleted    BIGINT := 0;
        v_checked_at TIMESTAMPTZ := clock_timestamp();
    BEGIN
        IF p_source_height IS NULL OR p_source_height < 0 THEN
            RAISE EXCEPTION 'api_work_refresh_full: source_height must be a non-negative block height, got %',
                p_source_height;
        END IF;

        PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));

        -- Everything is recomputed below; keys enqueued before this point are
        -- covered. Keys enqueued by concurrent writers after it stay queued.
        DELETE FROM structs.api_work_dirty;

        DROP TABLE IF EXISTS pg_temp.api_work_live_tmp;

        CREATE TEMP TABLE api_work_live_tmp ON COMMIT DROP AS
            SELECT w.object_id, w.player_id, w.target_id, w.category, w.block_start,
                   w.difficulty_target, w.location_type, w.location_id, w.planet_id
              FROM view.work_live w;

        CREATE INDEX ON api_work_live_tmp (category, object_id, target_id);

        WITH del AS (
            DELETE FROM structs.api_work aw
             WHERE NOT EXISTS (
                       SELECT 1 FROM api_work_live_tmp l
                        WHERE l.category  = aw.category
                          AND l.object_id = aw.object_id
                          AND l.target_id = aw.target_id
                   )
            RETURNING aw.category, aw.object_id, aw.target_id,
                      jsonb_build_object(
                          'player_id', aw.player_id, 'block_start', aw.block_start,
                          'difficulty_target', aw.difficulty_target, 'location_type', aw.location_type,
                          'location_id', aw.location_id, 'planet_id', aw.planet_id,
                          'source_height', aw.source_height) AS api_row
        ), logged_del AS (
            INSERT INTO structs.api_work_drift
                (checked_at, category, object_id, target_id, state, api_row, live_row, source_height)
            SELECT v_checked_at, d.category, d.object_id, d.target_id, 'extra', d.api_row, NULL, p_source_height
              FROM del d
             WHERE p_log
            RETURNING 1
        )
        SELECT count(*) INTO v_deleted FROM del;

        WITH ups AS (
            INSERT INTO structs.api_work AS aw
                (object_id, player_id, target_id, category, block_start,
                 difficulty_target, location_type, location_id, planet_id,
                 source_height, updated_at)
            SELECT l.object_id, l.player_id, l.target_id, l.category, l.block_start,
                   l.difficulty_target, l.location_type, l.location_id, l.planet_id,
                   p_source_height, NOW()
              FROM api_work_live_tmp l
            ON CONFLICT (category, object_id, target_id) DO UPDATE
               SET player_id         = EXCLUDED.player_id,
                   block_start       = EXCLUDED.block_start,
                   difficulty_target = EXCLUDED.difficulty_target,
                   location_type     = EXCLUDED.location_type,
                   location_id       = EXCLUDED.location_id,
                   planet_id         = EXCLUDED.planet_id,
                   source_height     = EXCLUDED.source_height,
                   updated_at        = EXCLUDED.updated_at
             WHERE (aw.player_id, aw.block_start, aw.difficulty_target,
                    aw.location_type, aw.location_id, aw.planet_id)
                   IS DISTINCT FROM
                   (EXCLUDED.player_id, EXCLUDED.block_start, EXCLUDED.difficulty_target,
                    EXCLUDED.location_type, EXCLUDED.location_id, EXCLUDED.planet_id)
            RETURNING (xmax = 0) AS is_insert, aw.category, aw.object_id, aw.target_id,
                      jsonb_build_object(
                          'player_id', aw.player_id, 'block_start', aw.block_start,
                          'difficulty_target', aw.difficulty_target, 'location_type', aw.location_type,
                          'location_id', aw.location_id, 'planet_id', aw.planet_id) AS live_row
        ), logged_ups AS (
            INSERT INTO structs.api_work_drift
                (checked_at, category, object_id, target_id, state, api_row, live_row, source_height)
            SELECT v_checked_at, u.category, u.object_id, u.target_id,
                   CASE WHEN u.is_insert THEN 'missing' ELSE 'stale' END, NULL, u.live_row, p_source_height
              FROM ups u
             WHERE p_log
            RETURNING 1
        )
        SELECT count(*) FILTER (WHERE is_insert),
               count(*) FILTER (WHERE NOT is_insert)
          INTO v_inserted, v_updated
          FROM ups;

        INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
        VALUES ('work', p_source_height, p_source_time, NOW())
        ON CONFLICT (model) DO UPDATE
           SET source_height = EXCLUDED.source_height,
               source_time   = EXCLUDED.source_time,
               refreshed_at  = EXCLUDED.refreshed_at;

        RETURN QUERY SELECT v_inserted, v_updated, v_deleted;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_refresh_full(BIGINT, TIMESTAMPTZ, BOOLEAN) IS
        'Full diff of structs.api_work against view.work_live (the previous per-block refresh). Drains api_work_dirty. With p_log, every correction is written to api_work_drift as missing/extra/stale: after the incremental refresh is live, rows here mean a dependency it does not track. Run hourly by pg_cron.';

    GRANT EXECUTE
        ON FUNCTION structs.api_work_refresh_full(BIGINT, TIMESTAMPTZ, BOOLEAN)
        TO structs_indexer;

    ------------------------------------------------------------------------
    -- 4. incremental per-block refresh, same signature as before
    ------------------------------------------------------------------------

    CREATE OR REPLACE FUNCTION structs.api_work_refresh(
        p_source_height BIGINT,
        p_source_time   TIMESTAMPTZ DEFAULT NOW()
    )
    RETURNS TABLE (inserted BIGINT, updated BIGINT, deleted BIGINT)
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        v_inserted BIGINT := 0;
        v_updated  BIGINT := 0;
        v_deleted  BIGINT := 0;
        v_dirty    INT;
        v_keys     VARCHAR[];
    BEGIN
        IF p_source_height IS NULL OR p_source_height < 0 THEN
            RAISE EXCEPTION 'api_work_refresh: source_height must be a non-negative block height, got %',
                p_source_height;
        END IF;

        PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));

        -- Drain the queue into this transaction.
        DROP TABLE IF EXISTS pg_temp.api_work_dirty_tmp;
        CREATE TEMP TABLE api_work_dirty_tmp (kind TEXT, id VARCHAR) ON COMMIT DROP;
        WITH drained AS (
            DELETE FROM structs.api_work_dirty RETURNING kind, id
        )
        INSERT INTO api_work_dirty_tmp (kind, id)
        SELECT kind, id FROM drained;

        GET DIAGNOSTICS v_dirty = ROW_COUNT;

        IF v_dirty = 0 THEN
            INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
            VALUES ('work', p_source_height, p_source_time, NOW())
            ON CONFLICT (model) DO UPDATE
               SET source_height = EXCLUDED.source_height,
                   source_time   = EXCLUDED.source_time,
                   refreshed_at  = EXCLUDED.refreshed_at;
            RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT;
            RETURN;
        END IF;

        IF v_dirty > 2000 THEN
            RETURN QUERY SELECT * FROM structs.api_work_refresh_full(p_source_height, p_source_time, FALSE);
            RETURN;
        END IF;

        -- Expand to the work-row targets that can be affected:
        --   target_id is struct.id for BUILD/MINE/REFINE and planet.id for RAID.
        SELECT array_agg(DISTINCT t) INTO v_keys
          FROM (
                SELECT d.id AS t FROM api_work_dirty_tmp d WHERE d.kind = 'struct'
                UNION ALL
                SELECT d.id FROM api_work_dirty_tmp d WHERE d.kind = 'planet'
                UNION ALL
                SELECT s.id FROM api_work_dirty_tmp d
                  JOIN structs.struct s ON s.location_id = d.id AND s.location_type = 'planet'
                 WHERE d.kind = 'planet'
                UNION ALL
                SELECT s.id FROM api_work_dirty_tmp d
                  JOIN structs.struct s ON s.owner = d.id
                 WHERE d.kind = 'player'
                UNION ALL
                SELECT p.id FROM api_work_dirty_tmp d
                  JOIN structs.planet p ON p.location_list_start = d.id
                 WHERE d.kind = 'fleet'
               ) k;

        IF v_keys IS NULL THEN
            -- dirty keys that influence nothing (e.g. a fleet raiding no planet)
            INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
            VALUES ('work', p_source_height, p_source_time, NOW())
            ON CONFLICT (model) DO UPDATE
               SET source_height = EXCLUDED.source_height,
                   source_time   = EXCLUDED.source_time,
                   refreshed_at  = EXCLUDED.refreshed_at;
            RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT;
            RETURN;
        END IF;

        -- Recompute only those targets through the specification.
        DROP TABLE IF EXISTS pg_temp.api_work_live_tmp;
        CREATE TEMP TABLE api_work_live_tmp ON COMMIT DROP AS
            SELECT w.object_id, w.player_id, w.target_id, w.category, w.block_start,
                   w.difficulty_target, w.location_type, w.location_id, w.planet_id
              FROM view.work_live w
             WHERE w.target_id = ANY (v_keys);

        WITH del AS (
            DELETE FROM structs.api_work aw
             WHERE aw.target_id = ANY (v_keys)
               AND NOT EXISTS (
                       SELECT 1 FROM api_work_live_tmp l
                        WHERE l.category  = aw.category
                          AND l.object_id = aw.object_id
                          AND l.target_id = aw.target_id
                   )
            RETURNING 1
        )
        SELECT count(*) INTO v_deleted FROM del;

        WITH ups AS (
            INSERT INTO structs.api_work AS aw
                (object_id, player_id, target_id, category, block_start,
                 difficulty_target, location_type, location_id, planet_id,
                 source_height, updated_at)
            SELECT l.object_id, l.player_id, l.target_id, l.category, l.block_start,
                   l.difficulty_target, l.location_type, l.location_id, l.planet_id,
                   p_source_height, NOW()
              FROM api_work_live_tmp l
            ON CONFLICT (category, object_id, target_id) DO UPDATE
               SET player_id         = EXCLUDED.player_id,
                   block_start       = EXCLUDED.block_start,
                   difficulty_target = EXCLUDED.difficulty_target,
                   location_type     = EXCLUDED.location_type,
                   location_id       = EXCLUDED.location_id,
                   planet_id         = EXCLUDED.planet_id,
                   source_height     = EXCLUDED.source_height,
                   updated_at        = EXCLUDED.updated_at
             WHERE (aw.player_id, aw.block_start, aw.difficulty_target,
                    aw.location_type, aw.location_id, aw.planet_id)
                   IS DISTINCT FROM
                   (EXCLUDED.player_id, EXCLUDED.block_start, EXCLUDED.difficulty_target,
                    EXCLUDED.location_type, EXCLUDED.location_id, EXCLUDED.planet_id)
            RETURNING (xmax = 0) AS is_insert
        )
        SELECT count(*) FILTER (WHERE is_insert),
               count(*) FILTER (WHERE NOT is_insert)
          INTO v_inserted, v_updated
          FROM ups;

        INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
        VALUES ('work', p_source_height, p_source_time, NOW())
        ON CONFLICT (model) DO UPDATE
           SET source_height = EXCLUDED.source_height,
               source_time   = EXCLUDED.source_time,
               refreshed_at  = EXCLUDED.refreshed_at;

        RETURN QUERY SELECT v_inserted, v_updated, v_deleted;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_refresh(BIGINT, TIMESTAMPTZ) IS
        'Incremental per-block refresh of structs.api_work: drains api_work_dirty, recomputes only the affected targets through view.work_live, records model ''work'' in api_refresh_state. Empty queue costs ~1 ms. Falls back to api_work_refresh_full() above 2,000 keys. Returns (inserted, updated, deleted).';

    ------------------------------------------------------------------------
    -- 5. hourly resync with logging; one full pass now so the queue and the
    --    table start from a known-consistent state.
    --
    -- A fresh database has no api_refresh_state.work row yet (sync-state has
    -- not run). Height 0 is the chain height before the first block; the
    -- pass records that row so the hourly job has a height to read.
    ------------------------------------------------------------------------

    SELECT cron.schedule(
        'api-work-refresh-full-hourly',
        '7 * * * *',
        $$SELECT * FROM structs.api_work_refresh_full((SELECT source_height FROM structs.api_refresh_state WHERE model = 'work'), now(), TRUE)$$
    );

    SELECT * FROM structs.api_work_refresh_full(
        COALESCE((SELECT source_height FROM structs.api_refresh_state WHERE model = 'work'), 0),
        COALESCE((SELECT source_time   FROM structs.api_refresh_state WHERE model = 'work'), NOW()),
        FALSE
    );

COMMIT;
