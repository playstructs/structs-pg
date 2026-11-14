-- Revert structs-pg:grid-connection-capacity-maximum-20261114 from pg
BEGIN;
SET LOCAL lock_timeout = '5s';
-- Refuse rollback once cap data exists: the old writer cannot represent it.
LOCK TABLE structs.grid IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.grid WHERE split_part(id, '-', 1) = '15') THEN
        RAISE EXCEPTION 'cannot revert connectionCapacityMaximum while cap rows exist';
    END IF;
END $$;
ALTER TABLE structs.grid DROP CONSTRAINT grid_connection_capacity_maximum_uint64;
    CREATE OR REPLACE FUNCTION cache.handle_event_grid(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
        grid_rowcount integer;
    BEGIN
        SELECT
            x."attributeId" AS attribute_id,
            x.value AS value
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "attributeId" text,
            value text
        );

        IF v.value = '' THEN
            DELETE FROM structs.grid WHERE id = v.attribute_id;
            GET DIAGNOSTICS grid_rowcount = ROW_COUNT;

            IF grid_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                    WHEN '0' THEN
                        INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '1' THEN
                        INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '2' THEN
                        INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '3' THEN
                        INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '4' THEN
                        INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '5' THEN
                        INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '6' THEN
                        INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '7' THEN
                        INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    ELSE

                END CASE;
            END IF;
        ELSE

            INSERT INTO structs.grid
            VALUES (
                v.attribute_id,

                CASE split_part(v.attribute_id, '-',1)
                WHEN '0' THEN 'ore'
                WHEN '1' THEN 'fuel'
                WHEN '2' THEN 'capacity'
                WHEN '3' THEN 'load'
                WHEN '4' THEN 'structsLoad'
                WHEN '5' THEN 'power'
                WHEN '6' THEN 'connectionCapacity'
                WHEN '7' THEN 'connectionCount'
                WHEN '8' THEN 'allocationPointerStart'
                WHEN '9' THEN 'allocationPointerEnd'
                WHEN '10' THEN 'proxyNonce'
                WHEN '11' THEN 'lastAction'
                WHEN '12' THEN 'nonce'
                WHEN '13' THEN 'ready'
                WHEN '14' THEN 'checkpointBlock'
                END,

                CASE split_part(v.attribute_id, '-', 2)
                WHEN '0' THEN 'guild'
                WHEN '1' THEN 'player'
                WHEN '2' THEN 'planet'
                WHEN '3' THEN 'reactor'
                WHEN '4' THEN 'substation'
                WHEN '5' THEN 'struct'
                WHEN '6' THEN 'allocation'
                WHEN '7' THEN 'infusion'
                WHEN '8' THEN 'address'
                WHEN '9' THEN 'fleet'
                WHEN '10' THEN 'provider'
                WHEN '11' THEN 'agreement'
                END,

                (split_part(v.attribute_id, '-', 3))::INTEGER,
                split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3),

                (v.value)::INTEGER,
                NOW()
                ) ON CONFLICT (id) DO UPDATE
                      SET
                          val = EXCLUDED.val,
                      updated_at = EXCLUDED.updated_at
                WHERE
                    structs.grid.val IS DISTINCT FROM EXCLUDED.val;

            GET DIAGNOSTICS grid_rowcount = ROW_COUNT;
            IF grid_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                                WHEN '0' THEN
                                 INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '1' THEN
                                 INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '2' THEN
                                 INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '3' THEN
                                 INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '4' THEN
                                 INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '5' THEN
                                 INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '6' THEN
                                 INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '7' THEN
                                 INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                ELSE

                END CASE;
            END IF;

        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;


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
