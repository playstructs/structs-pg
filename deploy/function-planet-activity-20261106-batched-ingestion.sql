-- Deploy structs-pg:function-planet-activity-20261106-batched-ingestion to pg

BEGIN;

CREATE OR REPLACE FUNCTION structs.planet_activity_attribute() RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_player_id CHARACTER VARYING;
    v_role TEXT;
BEGIN
    -- These categories produce at most one attribution. Avoid constructing
    -- the general UNION/DISTINCT result for each common status/clock update.
    IF NEW.category IN ('struct_status', 'struct_health', 'struct_move',
                        'struct_block_build_start', 'struct_block_ore_mine_start',
                        'struct_block_ore_refine_start')
       AND NEW.detail ? 'struct_id' THEN
        v_player_id := structs.object_owner(NEW.detail->>'struct_id');
        v_role := 'owner';
    ELSIF NEW.category IN ('shield_change', 'block_raid_start') THEN
        v_player_id := structs.object_owner(NEW.planet_id);
        v_role := 'planet_owner';
    ELSE
        INSERT INTO structs.planet_activity_player
            (time, planet_id, seq, player_id, role, category, block_height)
        SELECT NEW.time, NEW.planet_id, NEW.seq, a.player_id, a.role, NEW.category, NEW.block_height
          FROM structs.planet_activity_players(NEW.category, NEW.planet_id, NEW.detail) a
        ON CONFLICT DO NOTHING;
        RETURN NEW;
    END IF;

    IF v_player_id IS NOT NULL THEN
        INSERT INTO structs.planet_activity_player
            (time, planet_id, seq, player_id, role, category, block_height)
        VALUES (NEW.time, NEW.planet_id, NEW.seq, v_player_id, v_role, NEW.category, NEW.block_height)
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
END
$BODY$;

COMMIT;
