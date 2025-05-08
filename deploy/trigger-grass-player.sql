-- Deploy structs-pg:trigger-grass-player to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.player.' || NEW.guild_id || '.' || NEW.id, 'category', 'player_consensus'))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                            'subject','structs.player.' || NEW.guild_id || '.' || NEW.id,
                            'category', 'player_consensus',
                            'id', NEW.id,
                            'updated_at', NEW.updated_at,
                            'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLAYER_NOTIFY AFTER INSERT OR UPDATE ON structs.player
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_NOTIFY();


    CREATE OR REPLACE FUNCTION structs.PLAYER_META_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.player.' || NEW.guild_id || '.' || NEW.id, 'category', 'player_meta'))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                    'subject','structs.player.' || NEW.guild_id || '.' || NEW.id,
                    'category', 'player_meta',
                    'id', NEW.id,
                    'updated_at', NEW.updated_at,
                    'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLAYER_META_NOTIFY AFTER INSERT OR UPDATE ON structs.player_meta
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_META_NOTIFY();


    CREATE OR REPLACE FUNCTION structs.PLAYER_ADDRESS_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.player.' || NEW.guild_id || '.' || NEW.id, 'category', 'player_address'))::TEXT;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLAYER_ADDRESS_NOTIFY AFTER INSERT OR UPDATE ON structs.player_address
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_ADDRESS_NOTIFY();

COMMIT;
