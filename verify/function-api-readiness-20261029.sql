-- Verify structs-pg:function-api-readiness-20261029 on pg
BEGIN;
SELECT height,chain_id,indexed_height,observed_tip,protocol,observed_protocol,activation_height,
    api_contract,cache_epoch,inventory_authority,required_models,models,source_time,data_ready,transaction_ready
FROM structs.api_readiness(ARRAY['inventory','work']);
DO $$
BEGIN
    IF NOT has_function_privilege('structs_webapp','structs.api_readiness(text[])','EXECUTE')
        OR NOT has_function_privilege('structs_indexer','structs.api_readiness(text[])','EXECUTE') THEN
        RAISE EXCEPTION 'missing API readiness read privilege';
    END IF;
END $$;
ROLLBACK;
