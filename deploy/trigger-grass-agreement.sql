-- Deploy structs-pg:trigger-grass-agreement to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.AGREEMENT_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.agreement.' || NEW.provider_id || '.' || NEW.id, 'category', 'agreement'))::TEXT;
        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER AGREEMENT_NOTIFY AFTER INSERT OR UPDATE ON structs.agreement
        FOR EACH ROW EXECUTE PROCEDURE structs.AGREEMENT_NOTIFY();

COMMIT;
