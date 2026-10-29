-- Verify structs-pg:function-api-inventory-20261029-current-claims on pg
BEGIN;
SELECT address,denom,balance FROM structs.api_inventory_current_claims(ARRAY[]::VARCHAR[]);
SELECT inventory_authority FROM structs.api_refresh_state WHERE FALSE;
SELECT address,denom,balance FROM structs.api_inventory_address_expected(ARRAY[]::VARCHAR[],TRUE);
DO $$ BEGIN
    IF (SELECT attnotnull FROM pg_attribute WHERE attrelid='structs.api_inventory'::regclass AND attname='balance')
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='structs.api_inventory'::regclass
                      AND conname='api_inventory_unknown_claim' AND convalidated) THEN
        RAISE EXCEPTION 'inventory unknown-claim contract missing';
    END IF;
    IF NOT has_function_privilege('structs_indexer','structs.api_inventory_expected(boolean)','EXECUTE')
       OR NOT has_function_privilege('structs_indexer','structs.api_inventory_current_claims(character varying[])','EXECUTE')
       OR NOT has_function_privilege('structs_indexer','structs.api_inventory_address_expected(character varying[],boolean)','EXECUTE') THEN
        RAISE EXCEPTION 'missing indexer expected-inventory access';
    END IF;
    IF NOT has_table_privilege('structs_indexer','structs.infusion','SELECT')
       OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='structs.api_inventory'::regclass
                     AND tgname='api_inventory_claim_notify' AND tgenabled='O') THEN
        RAISE EXCEPTION 'missing claim source access or invalidation trigger';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid='structs.infusion_address_claim_idx'::regclass AND indisvalid) THEN
        RAISE EXCEPTION 'missing address-scoped claim index';
    END IF;
END $$;
ROLLBACK;
