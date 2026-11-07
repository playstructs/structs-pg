-- Revert structs-pg:function-planet-activity-20261106-batched-ingestion from pg

BEGIN;

CREATE OR REPLACE FUNCTION structs.planet_activity_attribute()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
    BEGIN
        INSERT INTO structs.planet_activity_player
            (time, planet_id, seq, player_id, role, category, block_height)
        SELECT NEW.time, NEW.planet_id, NEW.seq, a.player_id, a.role, NEW.category, NEW.block_height
          FROM structs.planet_activity_players(NEW.category, NEW.planet_id, NEW.detail) a
        ON CONFLICT DO NOTHING;

        RETURN NEW;
    END
    $function$;

COMMIT;
