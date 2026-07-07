-- Deploy structs-pg:trigger-grass-planet-activity-20260707-add-owner-player-id to pg
--
-- Append the owning player id to the grass planet subject and payload, in both
-- the full and stub branches. Owner resolves from the player_object sidecar,
-- falling back to planet.owner; unresolved owners use the 'noPlayer' sentinel,
-- matching structs.INVENTORY_NOTIFY().

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLANET_ACTIVITY_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
        _player_id CHARACTER VARYING;
    BEGIN
        -- Planet owner: prefer the player_object sidecar, fall back to planet.owner.
        SELECT COALESCE(NULLIF(po.player_id, ''), NULLIF(p.owner, ''))
          INTO _player_id
          FROM structs.planet p
          LEFT JOIN structs.player_object po ON po.object_id = p.id
         WHERE p.id = NEW.planet_id;

        _player_id := COALESCE(_player_id, 'noPlayer');

        payload := (to_jsonb(NEW) || jsonb_build_object(
                        'subject','structs.planet.' || NEW.planet_id || '.' || _player_id,
                        'player_id', _player_id))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                            'subject','structs.planet.' || NEW.planet_id || '.' || _player_id,
                            'planet_id', NEW.planet_id,
                            'player_id', _player_id,
                            'seq', NEW.seq,
                            'category', NEW.category,
                            'time', NEW.time,
                            'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
