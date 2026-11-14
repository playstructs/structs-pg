-- Verify structs-pg:grid-connection-capacity-maximum-20261114 on pg
BEGIN;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'structs.grid'::regclass
        AND conname = 'grid_connection_capacity_maximum_uint64' AND convalidated) THEN
        RAISE EXCEPTION 'connectionCapacityMaximum uint64 constraint missing';
    END IF;
    IF position('connectionCapacityMaximum' in pg_get_functiondef('cache.handle_event_grid(jsonb)'::regprocedure)) = 0
       OR position('connectionCapacityMaximum' in pg_get_functiondef('structs.grid_notify()'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'connectionCapacityMaximum handlers missing';
    END IF;
    IF EXISTS (SELECT 1 FROM structs.grid WHERE id ~ '^15-4-[0-9]+$'
        AND attribute_type IS DISTINCT FROM 'connectionCapacityMaximum') THEN
        RAISE EXCEPTION 'unrepaired connectionCapacityMaximum labels';
    END IF;
END $$;
ROLLBACK;
