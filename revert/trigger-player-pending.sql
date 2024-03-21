-- Revert structs-pg:trigger-player-pending from pg

BEGIN;

DROP FUNCTION structs.PLAYER_PENDING_MERGE();

COMMIT;
