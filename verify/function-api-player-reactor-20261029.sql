-- Verify structs-pg:function-api-player-reactor-20261029 on pg
BEGIN;
SELECT structs.api_player_reactor('1-0');
DO $$
BEGIN
    IF NOT has_function_privilege('structs_webapp','structs.api_player_reactor(text)','EXECUTE')
        OR NOT has_function_privilege('structs_indexer','structs.api_player_reactor(text)','EXECUTE') THEN
        RAISE EXCEPTION 'missing reactor API privileges';
    END IF;
END $$;
ROLLBACK;
