-- Revert structs-pg:influence-player-history-read-20261111 from pg
BEGIN;
REVOKE SELECT ON structs.influence_player_score_change FROM structs_webapp;
COMMIT;
