-- Deploy structs-pg:trigger-grass-inventory to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.INVENTORY_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.inventory.' || NEW.denom || '.' || NEW.object_id, 'category', NEW.action))::TEXT;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER INVENTORY_NOTIFY AFTER INSERT ON structs.ledger
        FOR EACH ROW EXECUTE PROCEDURE structs.INVENTORY_NOTIFY();

COMMIT;
