-- Deploy structs-pg:trigger-grass-current-block to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.CURRENT_BLOCK_NOTIFY() RETURNS trigger AS
    $BODY$
    BEGIN
        PERFORM pg_notify('grass',
                    jsonb_build_object(
                        'subject','consensus',
                        'category', 'block',
                        'updated_at', NEW.updated_at,
                        'height', NEW.height)::TEXT);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER CURRENT_BLOCK_NOTIFY AFTER INSERT OR UPDATE ON structs.current_block
        FOR EACH ROW EXECUTE PROCEDURE structs.CURRENT_BLOCK_NOTIFY();

COMMIT;
