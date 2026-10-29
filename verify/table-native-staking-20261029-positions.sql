-- Verify structs-pg:table-native-staking-20261029-positions on pg
BEGIN;
SELECT positions_complete FROM sync_state.native_staking_snapshot WHERE FALSE;
SELECT chain_id,address,validator,bonded,unbonding,unbonding_entries FROM sync_state.native_staking_position WHERE FALSE;
SELECT complete FROM sync_state.native_staking_position_state WHERE FALSE;
DO $$
BEGIN
    IF NOT has_table_privilege('structs_indexer','sync_state.native_staking_position','SELECT,INSERT,UPDATE,DELETE')
        OR NOT has_table_privilege('structs_indexer','sync_state.native_staking_position_state','SELECT') THEN
        RAISE EXCEPTION 'missing native position privileges';
    END IF;
END $$;
ROLLBACK;
