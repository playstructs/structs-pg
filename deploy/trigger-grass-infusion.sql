-- Deploy structs-pg:trigger-grass-infusion to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.INFUSION_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN

        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.grid.player.' || NEW.player_id, 'category', 'player_consensus'))::TEXT;

        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                    'subject','structs.grid.player.' || NEW.player_id,
                    'category', 'player_consensus',
                    'player_id', NEW.player_id,
                    'updated_at', NEW.updated_at,
                    'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER INFUSION_NOTIFY AFTER INSERT OR UPDATE ON structs.infusion
        FOR EACH ROW EXECUTE PROCEDURE structs.INFUSION_NOTIFY();

COMMIT;

