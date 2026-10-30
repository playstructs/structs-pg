-- Verify structs-pg:function-api-inventory-20261029-v022-ownership on pg
BEGIN;
SELECT source_height, source_time FROM structs.api_projection_boundary() WHERE FALSE;
SELECT guild_id, balance, denom FROM view.guild_inventory WHERE FALSE;
-- Later changes may delegate ownership aggregation to shared helpers. Verify
-- the callable contract here; tests/v022-inventory-ownership.sql exercises the
-- current-owner and boundary semantics without depending on function spelling.
SELECT owner_type,owner_id,denom,api_balance,ledger_balance
FROM structs.api_inventory_reconcile(FALSE) WHERE FALSE;
DO $$
BEGIN
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
