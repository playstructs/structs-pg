-- Verify structs-pg:table-work-20261030-uint64 on pg
BEGIN;
DO $$
DECLARE spec RECORD;
BEGIN
    FOR spec IN SELECT * FROM (VALUES
        ('struct_attribute','val','struct_attribute_val_uint64'),
        ('planet_attribute','val','planet_attribute_val_uint64'),
        ('struct_type','build_difficulty','struct_type_build_difficulty_uint64'),
        ('struct_type','ore_mining_difficulty','struct_type_ore_mining_difficulty_uint64'),
        ('struct_type','ore_refining_difficulty','struct_type_ore_refining_difficulty_uint64'),
        ('api_work','block_start','api_work_block_start_uint64'),
        ('api_work','difficulty_target','api_work_difficulty_target_uint64')
    ) required(rel,col,con) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_attribute
            WHERE attrelid=('structs.'||spec.rel)::regclass AND attname=spec.col
                AND atttypid='numeric'::regtype AND atttypmod=-1 AND NOT attisdropped)
            OR NOT EXISTS (SELECT 1 FROM pg_constraint
                WHERE conrelid=('structs.'||spec.rel)::regclass AND conname=spec.con AND convalidated) THEN
            RAISE EXCEPTION 'missing exact unsigned work contract %.%',spec.rel,spec.col;
        END IF;
    END LOOP;
    IF NOT has_table_privilege('structs_webapp','view.work','SELECT')
        OR NOT has_table_privilege('structs_indexer','view.work_live','SELECT') THEN
        RAISE EXCEPTION 'work view grants were not preserved';
    END IF;
END $$;
SELECT * FROM view.struct_status LIMIT 0;
SELECT * FROM view.struct LIMIT 0;
SELECT * FROM view.planet LIMIT 0;
SELECT * FROM view.work_live LIMIT 0;
SELECT * FROM view.work LIMIT 0;
ROLLBACK;
