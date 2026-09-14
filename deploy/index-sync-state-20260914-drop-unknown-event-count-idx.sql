-- Deploy structs-pg:index-sync-state-20260914-drop-unknown-event-count-idx to pg
--
-- sync_state.unknown_event_log holds ~150 rows but receives an UPDATE per
-- unknown event (8.3M so far). Every one of those updates bumps `count`,
-- and because unknown_event_log_count_idx covers `count` none of them can be
-- HOT: each update writes a new index entry and autovacuum has run 74k times
-- on this tiny table. The index has never been used (0 scans since the last
-- stats reset); ordering 150 rows by count needs no index.
--
-- sync-state's bootstrap.sql must drop the same CREATE INDEX so its doctor
-- probe does not report the index as missing.

BEGIN;

    DROP INDEX IF EXISTS sync_state.unknown_event_log_count_idx;

COMMIT;
