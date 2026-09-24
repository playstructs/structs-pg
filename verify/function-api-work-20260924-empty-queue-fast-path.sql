-- Verify structs-pg:function-api-work-20260924-empty-queue-fast-path on pg
--
-- Structure, then in this rolled-back transaction: drain the queue, check an
-- empty-queue call changes nothing and stamps api_refresh_state, then enqueue
-- a real key and check the incremental path still drains it. Nothing is
-- committed.

BEGIN;

    DO $$
    DECLARE
        v_height BIGINT;
        v_struct VARCHAR;
        r        RECORD;
    BEGIN
        IF (SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'structs' AND p.proname = 'api_work_refresh')
           NOT LIKE '%IF NOT EXISTS (SELECT 1 FROM structs.api_work_dirty)%' THEN
            RAISE EXCEPTION 'structs.api_work_refresh() has no empty-queue fast path';
        END IF;

        SELECT COALESCE(source_height, 0) INTO v_height
          FROM structs.api_refresh_state WHERE model = 'work';
        v_height := COALESCE(v_height, 0);

        PERFORM * FROM structs.api_work_refresh(v_height, now());
        IF EXISTS (SELECT 1 FROM structs.api_work_dirty) THEN
            RAISE EXCEPTION 'queue not drained by api_work_refresh()';
        END IF;

        SELECT * INTO r FROM structs.api_work_refresh(v_height + 1, now());
        IF (r.inserted, r.updated, r.deleted) <> (0, 0, 0) THEN
            RAISE EXCEPTION 'empty-queue refresh changed rows: %', r;
        END IF;
        IF (SELECT source_height FROM structs.api_refresh_state WHERE model = 'work') <> v_height + 1 THEN
            RAISE EXCEPTION 'empty-queue refresh did not stamp api_refresh_state';
        END IF;

        SELECT id INTO v_struct FROM structs.struct LIMIT 1;
        IF v_struct IS NULL THEN
            RAISE NOTICE 'api_work fast-path verify: no struct to enqueue; empty-queue checks passed';
            RETURN;
        END IF;
        INSERT INTO structs.api_work_dirty (kind, id) VALUES ('struct', v_struct);
        PERFORM * FROM structs.api_work_refresh(v_height + 2, now());
        IF EXISTS (SELECT 1 FROM structs.api_work_dirty) THEN
            RAISE EXCEPTION 'non-empty queue not drained after fast-path change';
        END IF;

        RAISE NOTICE 'api_work fast-path verify: empty and non-empty paths OK';
    END
    $$;

ROLLBACK;
