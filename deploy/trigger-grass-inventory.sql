-- Deploy structs-pg:trigger-grass-inventory to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.INVENTORY_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
        subject TEXT;

        guild_id CHARACTER VARYING;
        player_id CHARACTER VARYING;
    BEGIN

        SELECT player_address.guild_id, player_address.player_id INTO guild_id, player_id FROM structs.player_address where player_address.address = NEW.address;

        subject := 'structs.inventory.'
                        || NEW.denom || '.'
                        || (CASE guild_id WHEN '' THEN 'noGuild' ELSE COALESCE(guild_id, 'noGuild') END)::TEXT || '.'
                        || (CASE player_id WHEN '' THEN 'noPlayer' ELSE COALESCE(player_id, 'noPlayer') END)::TEXT || '.'
                        || NEW.address;


        payload := (to_jsonb(NEW) || jsonb_build_object('subject', subject, 'category', NEW.action))::TEXT;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER INVENTORY_NOTIFY AFTER INSERT ON structs.ledger
        FOR EACH ROW EXECUTE PROCEDURE structs.INVENTORY_NOTIFY();

COMMIT;
