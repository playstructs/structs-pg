-- Deploy structs-pg:trigger-grass-guild to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.GUILD_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.guild.' || NEW.id, 'category', 'guild_consensus'))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                            'subject','structs.guild.' || NEW.id,
                            'category', 'guild_consensus',
                            'id', NEW.id,
                            'updated_at', NEW.updated_at,
                            'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER GUILD_NOTIFY AFTER INSERT OR UPDATE ON structs.guild
        FOR EACH ROW EXECUTE PROCEDURE structs.GUILD_NOTIFY();


    CREATE OR REPLACE FUNCTION structs.GUILD_META_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.guild.' || NEW.id, 'category', 'guild_meta'))::TEXT;

        -- Notify payload is max 8000bytes.
        -- Create a smaller stub if the payload is larger
        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                    'subject','structs.guild.' || NEW.id,
                    'category', 'guild_meta',
                    'id', NEW.id,
                    'updated_at', NEW.updated_at,
                    'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER GUILD_META_NOTIFY AFTER INSERT OR UPDATE ON structs.guild_meta
        FOR EACH ROW EXECUTE PROCEDURE structs.GUILD_META_NOTIFY();

COMMIT;
