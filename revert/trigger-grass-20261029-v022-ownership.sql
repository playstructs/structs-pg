-- Revert structs-pg:trigger-grass-20261029-v022-ownership from pg
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.vault) THEN
        RAISE EXCEPTION 'cannot restore legacy notification ownership after vault state exists; restore a coordinated pre-upgrade snapshot';
    END IF;
END $$;
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

DROP TRIGGER INFUSION_NOTIFY ON structs.infusion;
CREATE TRIGGER INFUSION_NOTIFY AFTER INSERT OR UPDATE ON structs.infusion
    FOR EACH ROW EXECUTE PROCEDURE structs.INFUSION_NOTIFY();
COMMIT;
