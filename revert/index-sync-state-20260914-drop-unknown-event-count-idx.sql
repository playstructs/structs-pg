-- Revert structs-pg:index-sync-state-20260914-drop-unknown-event-count-idx from pg

BEGIN;

    CREATE INDEX IF NOT EXISTS unknown_event_log_count_idx
        ON sync_state.unknown_event_log (chain_id, count DESC);

COMMIT;
