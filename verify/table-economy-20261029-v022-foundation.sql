-- Verify structs-pg:table-economy-20261029-v022-foundation on pg
BEGIN;
SELECT owner_id, address, account_number FROM structs.vault WHERE FALSE;
SELECT address, owner_type, owner_id, guild_id, is_vault FROM structs.asset_owner WHERE FALSE;
SELECT owner_id, generator_disabled FROM structs.infusion WHERE FALSE;
SELECT deletion_pending, deletion_migration_substation_id FROM structs.substation WHERE FALSE;
SELECT rank_purchase_base_price, rank_purchase_step_increase, rank_purchase_minimum_rank,
       join_by_rank_purchase_enabled, bank_convert_in_fee, bank_convert_out_fee, charter_solver_id
  FROM structs.guild WHERE FALSE;
SELECT owner_id, power, squared_power, applied_bonus FROM structs.owner_reactor_diversity WHERE FALSE;
SELECT reactor_id, slash_revision, reconciled_slash_revision FROM structs.reactor_commission_revision WHERE FALSE;
SELECT singleton, active, cap_bps, min_validators FROM structs.reactor_stake_cap WHERE FALSE;
DO $$
DECLARE
    rel TEXT;
    privilege TEXT;
BEGIN
    IF NOT has_schema_privilege('structs_indexer', 'structs', 'USAGE')
       OR NOT has_schema_privilege('structs_webapp', 'structs', 'USAGE') THEN
        RAISE EXCEPTION 'missing economic schema access';
    END IF;
    FOREACH rel IN ARRAY ARRAY['vault', 'owner_reactor_diversity', 'reactor_commission_revision', 'reactor_stake_cap']
    LOOP
        FOREACH privilege IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'] LOOP
            IF NOT has_table_privilege('structs_indexer', 'structs.' || rel, privilege) THEN
                RAISE EXCEPTION 'missing indexer % on %', privilege, rel;
            END IF;
        END LOOP;
        IF NOT has_table_privilege('structs_webapp', 'structs.' || rel, 'SELECT') THEN
            RAISE EXCEPTION 'missing economy grants on %', rel;
        END IF;
    END LOOP;
    IF NOT has_table_privilege('structs_indexer', 'structs.asset_owner', 'SELECT')
       OR NOT has_table_privilege('structs_webapp', 'structs.asset_owner', 'SELECT') THEN
        RAISE EXCEPTION 'missing asset_owner read grant';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'structs.vault'::regclass
        AND attname = 'account_number' AND atttypid = 'numeric'::regtype AND atttypmod = -1 AND attnotnull) THEN
        RAISE EXCEPTION 'vault account number must be unscaled, non-null numeric';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid = 'structs.infusion_owner_destination_address_idx'::regclass
        AND indisvalid AND indisready) THEN
        RAISE EXCEPTION 'infusion owner index is not ready';
    END IF;
END $$;
ROLLBACK;
