-- Verify structs-pg:function-api-work-20261108-target-lookups on pg
BEGIN;
DO $$
DECLARE source TEXT;
BEGIN
    SELECT prosrc INTO STRICT source FROM pg_proc
     WHERE oid='structs.api_work_refresh(bigint,timestamptz)'::regprocedure;
    IF source NOT LIKE '%FROM unnest(v_keys) AS k(id)%'
       OR source NOT LIKE '%CROSS JOIN LATERAL%'
       OR source NOT LIKE '%WHERE wk.target_id = k.id%'
       OR source NOT LIKE '%OFFSET 0%'
       OR source NOT LIKE '%IF NOT EXISTS (SELECT 1 FROM structs.api_work_dirty)%'
       OR source NOT LIKE '%IF v_dirty > 2000 THEN%'
       OR source NOT LIKE '%structs.api_work_refresh_full(p_source_height, p_source_time, FALSE)%'
       OR NOT has_function_privilege('structs_indexer',
            'structs.api_work_refresh(bigint,timestamptz)', 'EXECUTE')
    THEN RAISE EXCEPTION 'target lookup refresh contract is incomplete'; END IF;
END $$;
ROLLBACK;
