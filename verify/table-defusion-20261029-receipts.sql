-- Verify structs-pg:table-defusion-20261029-receipts on pg
BEGIN;
SELECT chain_id,block_height,tx_index,event_index,source_validator_address,legacy_observed_height,
    reconciled_height,retired_height,pending_state,amount_p,amount FROM structs.defusion_current WHERE FALSE;
SELECT receipts_pending FROM sync_state.native_staking_snapshot WHERE FALSE;
DO $$
DECLARE privilege TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid='structs.defusion_source_event_uidx'::regclass
        AND indisunique AND indisvalid) THEN RAISE EXCEPTION 'missing receipt identity'; END IF;
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname='defusion_cleaner' AND active) THEN
        RAISE EXCEPTION 'wall-clock receipt cleanup is still scheduled';
    END IF;
    FOREACH privilege IN ARRAY ARRAY['SELECT','INSERT','UPDATE'] LOOP
        IF NOT has_table_privilege('structs_indexer','structs.defusion',privilege) THEN
            RAISE EXCEPTION 'missing receipt privilege %',privilege;
        END IF;
    END LOOP;
    IF NOT has_table_privilege('structs_webapp','structs.defusion_current','SELECT') THEN
        RAISE EXCEPTION 'missing receipt privileges';
    END IF;
END $$;
ROLLBACK;
