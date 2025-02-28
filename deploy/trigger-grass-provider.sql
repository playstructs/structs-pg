-- Deploy structs-pg:trigger-grass-provider to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PROVIDER_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.provider.' || NEW.substation_id || '.' || NEW.id, 'category', 'provider'))::TEXT;
        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PROVIDER_NOTIFY AFTER INSERT OR UPDATE ON structs.provider
        FOR EACH ROW EXECUTE PROCEDURE structs.PROVIDER_NOTIFY();

COMMIT;
