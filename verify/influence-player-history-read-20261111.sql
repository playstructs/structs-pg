-- Verify structs-pg:influence-player-history-read-20261111 on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT build_id,height,player,sector,unique_delta,claim_delta FROM structs.influence_player_score_change WHERE false;
ROLLBACK;
