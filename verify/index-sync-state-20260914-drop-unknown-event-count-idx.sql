-- Verify structs-pg:index-sync-state-20260914-drop-unknown-event-count-idx on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regclass('sync_state.unknown_event_log_count_idx') IS NOT NULL THEN
            RAISE EXCEPTION 'expected sync_state.unknown_event_log_count_idx to be dropped';
        END IF;
    END
    $$;

ROLLBACK;
