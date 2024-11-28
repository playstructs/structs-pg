-- Deploy structs-pg:trigger-grass-planet-activity to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLANET_ACTIVITY_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.planet.' || NEW.planet_id))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                            'subject','structs.planet.' || NEW.planet_id,
                            'planet_id', NEW.planet_id,
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

    CREATE TRIGGER PLANET_ACTIVITY_NOTIFY AFTER INSERT ON structs.planet_activity
        FOR EACH ROW EXECUTE PROCEDURE structs.PLANET_ACTIVITY_NOTIFY();

COMMIT;
