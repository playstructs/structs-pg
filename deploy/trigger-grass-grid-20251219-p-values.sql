-- Deploy structs-pg:trigger-grass-grid-20251219-p-values to pg

BEGIN;

CREATE OR REPLACE FUNCTION structs.GRID_NOTIFY() RETURNS trigger AS
$BODY$
DECLARE
    payload TEXT;
BEGIN



    -- TODO change to case w\ better support for the status field

    payload := jsonb_build_object(
            'subject','structs.grid.' || NEW.object_type || '.' || NEW.object_id,
            'category', NEW.attribute_type,
            'object_id', NEW.object_id,
            'object_type', NEW.object_type,
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
