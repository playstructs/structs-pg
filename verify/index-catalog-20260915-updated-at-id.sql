-- Verify structs-pg:index-catalog-20260915-updated-at-id on pg
--
-- All seven indexes exist and are valid, and the planner actually picks one
-- for the heaviest statement shape (no Sort node).

BEGIN;

    DO $$
    DECLARE
        v_name TEXT;
        v_plan JSONB;
    BEGIN
        FOREACH v_name IN ARRAY ARRAY[
            'struct_updated_at_id_idx',
            'struct_attribute_updated_at_id_idx',
            'planet_attribute_updated_at_id_idx',
            'planet_attribute_attribute_type_updated_at_id_idx',
            'grid_updated_at_id_idx',
            'grid_attribute_object_updated_at_id_idx',
            'planet_updated_at_id_idx'
        ] LOOP
            IF NOT EXISTS (
                SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
                 WHERE c.relname = v_name AND c.relnamespace = 'structs'::regnamespace
                   AND i.indisvalid
            ) THEN
                RAISE EXCEPTION 'index structs.% missing or invalid', v_name;
            END IF;
        END LOOP;

        EXECUTE 'EXPLAIN (FORMAT JSON) SELECT id FROM structs.struct_attribute ORDER BY updated_at DESC NULLS LAST, id LIMIT 100 OFFSET 100'
           INTO v_plan;
        IF v_plan::text LIKE '%"Node Type": "Sort"%' THEN
            RAISE EXCEPTION 'struct_attribute listing still sorts instead of using struct_attribute_updated_at_id_idx';
        END IF;
    END
    $$;

ROLLBACK;
