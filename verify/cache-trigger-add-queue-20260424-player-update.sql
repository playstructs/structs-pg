-- Verify structs-pg:cache-trigger-add-queue-20260424-player-update on pg

BEGIN;

SELECT 1 / (to_regprocedure('cache.handle_event_player(jsonb)') IS NOT NULL)::int;
ROLLBACK;
