-- Revert structs-pg:function-api-player-reactor-20261029 from pg
BEGIN;
DROP FUNCTION structs.api_player_reactor(TEXT);
COMMIT;
