-- Deploy structs-pg:trigger-grass-inventory to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.INVENTORY_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        _payload TEXT;
        _subject TEXT;

        _guild_id CHARACTER VARYING;
        _player_id CHARACTER VARYING;
        _counterparty_player_id CHARACTER VARYING;
        _counterparty_guild_id CHARACTER VARYING;
    BEGIN

        SELECT player_address.guild_id, player_address.player_id INTO _guild_id, _player_id FROM structs.player_address where player_address.address = NEW.address;
        SELECT player_address.guild_id, player_address.player_id INTO _counterparty_guild_id, _counterparty_player_id FROM structs.player_address where player_address.address = NEW.counterparty;

        _guild_id := (CASE _guild_id WHEN '' THEN 'noGuild' ELSE COALESCE(_guild_id, 'noGuild') END);
        _player_id := (CASE _player_id WHEN '' THEN 'noPlayer' ELSE COALESCE(_player_id, 'noPlayer') END);

        _counterparty_player_id := (CASE _counterparty_player_id WHEN '' THEN 'noPlayer' ELSE COALESCE(_counterparty_player_id, 'noPlayer') END);
        _counterparty_guild_id := (CASE _counterparty_guild_id WHEN '' THEN 'noGuild' ELSE COALESCE(_counterparty_guild_id, 'noGuild') END);

        _subject := 'structs.inventory.'
                        || NEW.denom || '.'
                        || _guild_id::TEXT || '.'
                        || _player_id::TEXT || '.'
                        || NEW.address;


        _payload := (to_jsonb(NEW)
                        || jsonb_build_object(
                            'subject', _subject,
                            'category', NEW.action,
                            'player_id', _player_id,
                            'counterparty_player_id', _counterparty_player_id,
                            'counterparty_guild_id', _counterparty_guild_id,
                            'guild_id', _guild_id))::TEXT;

        PERFORM pg_notify('grass', _payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER INVENTORY_NOTIFY AFTER INSERT ON structs.ledger
        FOR EACH ROW EXECUTE PROCEDURE structs.INVENTORY_NOTIFY();

COMMIT;
