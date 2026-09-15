-- Verify structs-pg:function-api-work-20260915-incremental-refresh on pg
--
-- Structure, then a functional test in this rolled-back transaction: change a
-- real build clock, check the trigger enqueued the struct, run the incremental
-- refresh, and check api_work now matches view.work_live for that struct and
-- the queue is empty. Nothing is committed.

BEGIN;

    DO $$
    DECLARE
        v_struct  VARCHAR;
        v_attr_id VARCHAR;
        v_height  BIGINT;
        v_n       INT;
        v_diff    INT;
        r         RECORD;
    BEGIN
        -- structure ---------------------------------------------------------
        PERFORM 1 FROM pg_tables WHERE schemaname = 'structs' AND tablename = 'api_work_dirty';
        IF NOT FOUND THEN RAISE EXCEPTION 'structs.api_work_dirty missing'; END IF;

        PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'structs' AND p.proname = 'api_work_mark_dirty';
        IF NOT FOUND THEN RAISE EXCEPTION 'structs.api_work_mark_dirty() missing'; END IF;

        PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'structs' AND p.proname = 'api_work_refresh_full';
        IF NOT FOUND THEN RAISE EXCEPTION 'structs.api_work_refresh_full() missing'; END IF;

        IF (SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'structs' AND p.proname = 'api_work_refresh') NOT LIKE '%api_work_dirty%' THEN
            RAISE EXCEPTION 'structs.api_work_refresh() is not the incremental version';
        END IF;

        SELECT count(*) INTO v_n
          FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
         WHERE c.relnamespace = 'structs'::regnamespace
           AND t.tgname IN ('api_work_dirty_ins', 'api_work_dirty_upd', 'api_work_dirty_del')
           AND c.relname IN ('struct', 'struct_attribute', 'planet_attribute', 'grid', 'planet', 'fleet');
        IF v_n <> 18 THEN
            RAISE EXCEPTION 'expected 18 api_work_dirty triggers, found %', v_n;
        END IF;

        PERFORM 1 FROM pg_indexes WHERE schemaname = 'structs' AND indexname = 'struct_location_id_idx';
        IF NOT FOUND THEN RAISE EXCEPTION 'structs.struct_location_id_idx missing'; END IF;

        PERFORM 1 FROM cron.job WHERE jobname = 'api-work-refresh-full-hourly';
        IF NOT FOUND THEN RAISE EXCEPTION 'cron job api-work-refresh-full-hourly missing'; END IF;

        -- functional --------------------------------------------------------
        SELECT source_height INTO v_height FROM structs.api_refresh_state WHERE model = 'work';

        -- a struct with a live BUILD row and a build clock
        SELECT w.target_id, sa.id INTO v_struct, v_attr_id
          FROM structs.api_work w
          JOIN structs.struct_attribute sa
            ON sa.object_id = w.target_id AND sa.attribute_type = 'blockStartBuild'
         WHERE w.category = 'BUILD'
         LIMIT 1;

        IF v_struct IS NULL THEN
            RAISE NOTICE 'api_work incremental verify: no BUILD row with a build clock to test against; structure checks passed';
            RETURN;
        END IF;

        DELETE FROM structs.api_work_dirty;

        -- no-op update must not enqueue
        UPDATE structs.struct_attribute SET val = val WHERE id = v_attr_id;
        IF EXISTS (SELECT 1 FROM structs.api_work_dirty) THEN
            RAISE EXCEPTION 'no-op update enqueued a dirty key';
        END IF;

        -- real change must enqueue exactly the struct
        UPDATE structs.struct_attribute SET val = val + 1 WHERE id = v_attr_id;
        IF NOT EXISTS (SELECT 1 FROM structs.api_work_dirty WHERE kind = 'struct' AND id = v_struct) THEN
            RAISE EXCEPTION 'build clock change did not enqueue struct %', v_struct;
        END IF;

        -- incremental refresh applies it
        SELECT * INTO r FROM structs.api_work_refresh(v_height, now());
        -- >= 1: a block committing between the DELETE above and this call can
        -- legitimately add its own keys to the drain
        IF r.updated < 1 THEN
            RAISE EXCEPTION 'incremental refresh reported updated=% (expected >= 1) after a build clock change', r.updated;
        END IF;
        IF EXISTS (SELECT 1 FROM structs.api_work_dirty) THEN
            RAISE EXCEPTION 'queue not drained by api_work_refresh()';
        END IF;

        SELECT count(*) INTO v_diff FROM (
            SELECT object_id, player_id, target_id, category, block_start, difficulty_target, location_type, location_id, planet_id
              FROM view.work_live WHERE target_id = v_struct
            EXCEPT
            SELECT object_id, player_id, target_id, category, block_start, difficulty_target, location_type, location_id, planet_id
              FROM structs.api_work WHERE target_id = v_struct
        ) x;
        IF v_diff <> 0 THEN
            RAISE EXCEPTION 'api_work differs from view.work_live for struct % after incremental refresh', v_struct;
        END IF;

        -- empty queue is a no-op
        SELECT * INTO r FROM structs.api_work_refresh(v_height, now());
        IF (r.inserted, r.updated, r.deleted) <> (0, 0, 0) THEN
            RAISE EXCEPTION 'empty-queue refresh changed rows: %', r;
        END IF;

        RAISE NOTICE 'api_work incremental verify: trigger + refresh OK on struct %', v_struct;
    END
    $$;

ROLLBACK;
