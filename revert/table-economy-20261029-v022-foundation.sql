-- Revert structs-pg:table-economy-20261029-v022-foundation from pg
-- Stop dependent consumers first. Never discard authoritative release state.
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.vault)
       OR EXISTS (SELECT 1 FROM structs.owner_reactor_diversity)
       OR EXISTS (SELECT 1 FROM structs.reactor_commission_revision)
       OR EXISTS (SELECT 1 FROM structs.reactor_stake_cap)
       OR EXISTS (SELECT 1 FROM structs.infusion WHERE NULLIF(owner_id, '') IS NOT NULL OR generator_disabled)
       OR EXISTS (SELECT 1 FROM structs.substation WHERE deletion_pending OR deletion_migration_substation_id <> '')
       OR EXISTS (SELECT 1 FROM structs.guild WHERE rank_purchase_base_price <> 0
           OR rank_purchase_step_increase <> 0 OR rank_purchase_minimum_rank <> 0
           OR join_by_rank_purchase_enabled OR bank_convert_in_fee IS NOT NULL
           OR bank_convert_out_fee IS NOT NULL OR charter_solver_id IS NOT NULL)
    THEN
        RAISE EXCEPTION 'v0.22 economy state exists; retain additive schema or restore a verified checkpoint';
    END IF;
END $$;
DROP VIEW structs.asset_owner;
DROP TABLE structs.vault, structs.owner_reactor_diversity,
    structs.reactor_commission_revision, structs.reactor_stake_cap;
DROP INDEX structs.infusion_owner_destination_address_idx;
ALTER TABLE structs.infusion DROP COLUMN owner_id, DROP COLUMN generator_disabled;
ALTER TABLE structs.substation DROP COLUMN deletion_pending, DROP COLUMN deletion_migration_substation_id;
ALTER TABLE structs.guild DROP COLUMN rank_purchase_base_price,
    DROP COLUMN rank_purchase_step_increase, DROP COLUMN rank_purchase_minimum_rank,
    DROP COLUMN join_by_rank_purchase_enabled, DROP COLUMN bank_convert_in_fee,
    DROP COLUMN bank_convert_out_fee, DROP COLUMN charter_solver_id;
-- Retain schema USAGE: existing indexer tables also need it.
COMMIT;
