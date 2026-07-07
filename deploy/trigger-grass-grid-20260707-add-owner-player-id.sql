-- Deploy structs-pg:trigger-grass-grid-20260707-add-owner-player-id to pg
--
-- Append the owning player id to the grass grid subject and payload.
-- Layered on top of trigger-grass-grid-20251219-p-values (retains value_p /
-- unit-formatted value / value_old_p / value_old); only owner resolution and
-- the trailing .player_id subject segment are new. Unresolved owners use the
-- 'noPlayer' sentinel, matching structs.INVENTORY_NOTIFY().

BEGIN;

CREATE OR REPLACE FUNCTION structs.GRID_NOTIFY() RETURNS trigger AS
$BODY$
DECLARE
    payload TEXT;
    _player_id CHARACTER VARYING;
BEGIN

    -- Resolve the owning player for this grid object.
    IF NEW.object_type = 'player' THEN
        _player_id := NEW.object_id;               -- object_id IS the player id
    ELSE
        SELECT po.player_id INTO _player_id
          FROM structs.player_object po
         WHERE po.object_id = NEW.object_id;

        -- Planet fallback if the player_object sidecar row isn't present yet.
        IF _player_id IS NULL AND NEW.object_type = 'planet' THEN
            SELECT p.owner INTO _player_id
              FROM structs.planet p
             WHERE p.id = NEW.object_id;
        END IF;
    END IF;

    _player_id := COALESCE(NULLIF(_player_id, ''), 'noPlayer');

    -- TODO change to case w\ better support for the status field

    payload := jsonb_build_object(
            'subject','structs.grid.' || NEW.object_type || '.' || NEW.object_id || '.' || _player_id,
            'category', NEW.attribute_type,
            'object_id', NEW.object_id,
            'object_type', NEW.object_type,
            'player_id', _player_id,
            'attribute_type', NEW.attribute_type,
            'value_p',NEW.val,
            'value', (CASE NEW.attribute_type
                          WHEN 'ore' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'ore')
                          WHEN 'fuel' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'ualpha')
                          WHEN 'capacity' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'milliwatt')
                          WHEN 'load' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'milliwatt')
                          WHEN 'structsLoad' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'milliwatt')
                          WHEN 'power' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'milliwatt')
                          WHEN 'connectionCapacity' THEN structs.UNIT_LEGACY_FORMAT(NEW.val, 'milliwatt')
                          WHEN 'connectionCount' THEN NEW.val
                          WHEN 'allocationPointerStart' THEN NEW.val
                          WHEN 'allocationPointerEnd' THEN NEW.val
                          WHEN 'proxyNonce' THEN NEW.val
                          WHEN 'lastAction' THEN NEW.val
                          WHEN 'nonce' THEN NEW.val
                          WHEN 'ready' THEN NEW.val
                          WHEN 'checkpointBlock' THEN NEW.val
                END),
            'value_old_p', OLD.val,
            'value_old', (CASE NEW.attribute_type
                              WHEN 'ore' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'ore')
                              WHEN 'fuel' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'ualpha')
                              WHEN 'capacity' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'milliwatt')
                              WHEN 'load' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'milliwatt')
                              WHEN 'structsLoad' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'milliwatt')
                              WHEN 'power' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'milliwatt')
                              WHEN 'connectionCapacity' THEN structs.UNIT_LEGACY_FORMAT(OLD.val, 'milliwatt')
                              WHEN 'connectionCount' THEN OLD.val
                              WHEN 'allocationPointerStart' THEN OLD.val
                              WHEN 'allocationPointerEnd' THEN OLD.val
                              WHEN 'proxyNonce' THEN OLD.val
                              WHEN 'lastAction' THEN OLD.val
                              WHEN 'nonce' THEN OLD.val
                              WHEN 'ready' THEN OLD.val
                              WHEN 'checkpointBlock' THEN OLD.val
                END),
            'updated_at', NEW.updated_at)::TEXT;

    PERFORM pg_notify('grass', payload);

    RETURN NEW;
END
$BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
