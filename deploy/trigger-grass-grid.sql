-- Deploy structs-pg:trigger-grass-grid to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.GRID_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := jsonb_build_object(
                        'subject','structs.grid.' || NEW.object_type || '.' || NEW.object_id,
                        'category', NEW.attribute_type,
                        'object_id', NEW.object_id,
                        'object_type', NEW.object_type,
                        'value', NEW.val,
                        'updated_at', NEW.updated_at)::TEXT;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER GRID_NOTIFY AFTER INSERT OR UPDATE ON structs.grid
        FOR EACH ROW EXECUTE PROCEDURE structs.GRID_NOTIFY();

COMMIT;
