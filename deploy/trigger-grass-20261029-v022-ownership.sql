-- Deploy structs-pg:trigger-grass-20261029-v022-ownership to pg
BEGIN;

CREATE OR REPLACE FUNCTION structs.INVENTORY_NOTIFY() RETURNS trigger AS
$BODY$
DECLARE
    _owner structs.asset_owner%ROWTYPE;
    _counterparty structs.asset_owner%ROWTYPE;
    _guild_id TEXT;
    _player_id TEXT;
    _subject TEXT;
    _metadata JSONB;
    _payload TEXT;
BEGIN
    SELECT * INTO _owner FROM structs.asset_owner WHERE address = NEW.address;
    SELECT * INTO _counterparty FROM structs.asset_owner WHERE address = NEW.counterparty;
    _guild_id := COALESCE(NULLIF(_owner.guild_id, ''), 'noGuild');
    _player_id := CASE WHEN _owner.owner_type = 'player' THEN _owner.owner_id ELSE 'noPlayer' END;
    _subject := 'structs.inventory.' || NEW.denom || '.' || _guild_id || '.' || _player_id || '.' || COALESCE(NEW.address, 'noAddress');
    _metadata := jsonb_build_object(
        'subject', _subject, 'category', NEW.action,
        'guild_id', _guild_id, 'player_id', _player_id,
        'owner_type', _owner.owner_type, 'owner_id', _owner.owner_id, 'is_vault', COALESCE(_owner.is_vault, FALSE),
        'counterparty_player_id', CASE WHEN _counterparty.owner_type = 'player' THEN _counterparty.owner_id ELSE 'noPlayer' END,
        'counterparty_guild_id', COALESCE(NULLIF(_counterparty.guild_id, ''), 'noGuild'),
        'counterparty_owner_type', _counterparty.owner_type, 'counterparty_owner_id', _counterparty.owner_id,
        'amount_p_exact', NEW.amount_p::TEXT, 'id_exact', NEW.id::TEXT,
        'block_height_exact', NEW.block_height::TEXT
    );
    _payload := (to_jsonb(NEW) || _metadata)::TEXT;
    IF octet_length(_payload) > 7995 THEN
        -- A notification is invalidation, never the sole payment evidence.
        -- Keep the row/source identity so clients can fetch the full record.
        _payload := (_metadata || jsonb_build_object(
            'id', NEW.id, 'time', NEW.time, 'block_height', NEW.block_height,
            'chain_id', NEW.chain_id, 'tx_index', NEW.tx_index,
            'msg_index', NEW.msg_index, 'event_index', NEW.event_index,
            'stub', TRUE))::TEXT;
    END IF;
    PERFORM pg_notify('grass', _payload);
    RETURN NEW;
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

CREATE OR REPLACE FUNCTION structs.INFUSION_NOTIFY() RETURNS trigger AS
$BODY$
DECLARE
    _row JSONB;
    _old_owner TEXT;
    _new_owner TEXT;
    _live_owner TEXT;
    _owner TEXT;
    _kind TEXT;
    _metadata JSONB;
    _payload TEXT;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        _old_owner := COALESCE(NULLIF(OLD.owner_id, ''), OLD.player_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        _new_owner := COALESCE(NULLIF(NEW.owner_id, ''), NEW.player_id);
        _row := to_jsonb(NEW);
    ELSE
        _row := to_jsonb(OLD);
    END IF;
    SELECT owner_id INTO _live_owner FROM structs.asset_owner WHERE address = _row->>'address';
    FOR _owner IN SELECT DISTINCT value FROM unnest(ARRAY[_old_owner, _new_owner, _live_owner]) value
                  WHERE value ~ '^[01]-[1-9][0-9]*$'
    LOOP
        _kind := CASE WHEN left(_owner, 2) = '1-' THEN 'player' ELSE 'guild' END;
        _metadata := jsonb_build_object(
            'subject', 'structs.grid.' || _kind || '.' || _owner,
            'category', _kind || '_consensus',
            'notification_owner_type', _kind, 'notification_owner_id', _owner,
            'previous_owner_id', _old_owner, 'operation', lower(TG_OP), 'invalidates', 'infusion',
            'fuel_p_exact', _row->>'fuel_p', 'defusing_p_exact', _row->>'defusing_p',
            'power_p_exact', _row->>'power_p', 'ratio_p_exact', _row->>'ratio_p'
        );
        _payload := (_row || _metadata)::TEXT;
        IF octet_length(_payload) > 7995 THEN
            _payload := (_metadata || jsonb_build_object(
                'destination_id', _row->>'destination_id', 'address', _row->>'address',
                'owner_id', COALESCE(_new_owner, _old_owner),
                'updated_at', _row->>'updated_at', 'stub', TRUE))::TEXT;
        END IF;
        PERFORM pg_notify('grass', _payload);
    END LOOP;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

DROP TRIGGER INFUSION_NOTIFY ON structs.infusion;
CREATE TRIGGER INFUSION_NOTIFY AFTER INSERT OR UPDATE OR DELETE ON structs.infusion
    FOR EACH ROW EXECUTE FUNCTION structs.INFUSION_NOTIFY();

COMMIT;
