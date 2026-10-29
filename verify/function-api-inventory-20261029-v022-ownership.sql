-- Verify structs-pg:function-api-inventory-20261029-v022-ownership on pg
BEGIN;
SELECT source_height, source_time FROM structs.api_projection_boundary() WHERE FALSE;
SELECT guild_id, balance, denom FROM view.guild_inventory WHERE FALSE;
DO $$
BEGIN
    IF position('structs.asset_owner' IN pg_get_functiondef('structs.api_inventory_reconcile(boolean)'::regprocedure)) = 0
       OR position('api_projection_boundary' IN pg_get_functiondef('structs.api_inventory_reconcile(boolean)'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'inventory reconciler lacks current ownership/boundary contract';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname='api-work-refresh-full-hourly'
        AND command='SELECT * FROM structs.api_work_refresh_scheduled();' AND active) THEN
        RAISE EXCEPTION 'work maintenance does not use the serialized snapshot wrapper';
    END IF;
    IF NOT has_function_privilege('structs_indexer','structs.api_projection_boundary()','EXECUTE')
       OR NOT has_function_privilege('structs_indexer','structs.api_work_refresh_scheduled()','EXECUTE')
       OR NOT has_table_privilege('structs_indexer','structs.api_inventory_drift','INSERT')
       OR NOT has_table_privilege('structs_indexer','structs.api_work_drift','INSERT') THEN
        RAISE EXCEPTION 'missing projection maintenance privileges';
    END IF;
END $$;
ROLLBACK;
