-- Revert structs-pg:cache-trigger-add-queue-20260207-add-destroyed-block from pg

BEGIN;


CREATE OR REPLACE FUNCTION cache.handle_event_struct_attribute(payload jsonb)
    RETURNS void AS
$BODY$
DECLARE
    v record;
    struct_attr_rowcount integer;
BEGIN
    SELECT
        x."attributeId" AS attribute_id,
        x.value AS value
    INTO v
    FROM jsonb_to_record(payload) AS x(
                                       "attributeId" text,
                                       value text
        );

    IF v.value = '' OR (v.value)::INTEGER = 0 THEN
        DELETE FROM structs.struct_attribute WHERE id = v.attribute_id;
        GET DIAGNOSTICS struct_attr_rowcount = ROW_COUNT;

        IF struct_attr_rowcount > 0 THEN
            CASE split_part(v.attribute_id, '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                --WHEN '1' THEN
                --   INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                ELSE
                END CASE;
        END IF;
    ELSE

        INSERT INTO structs.struct_attribute
        VALUES (
                   v.attribute_id,

                   split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3),
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
                   CASE split_part(v.attribute_id, '-', 4) WHEN '' THEN 0 ELSE (split_part(v.attribute_id, '-', 4))::INTEGER END,

                   CASE split_part(v.attribute_id, '-', 1)
                       WHEN '0' THEN 'health'
                       WHEN '1' THEN 'status'
                       WHEN '2' THEN 'blockStartBuild'
                       WHEN '3' THEN 'blockStartOreMine'
                       WHEN '4' THEN 'blockStartOreRefine'
                       WHEN '5' THEN 'protectedStructIndex'
                       WHEN '6' THEN 'typeCount'
                       END,
                   (v.value)::INTEGER,
                   NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at
        WHERE
                structs.struct_attribute.val IS DISTINCT FROM EXCLUDED.val;

        GET DIAGNOSTICS struct_attr_rowcount = ROW_COUNT;
        IF struct_attr_rowcount > 0 THEN
            CASE split_part(v.attribute_id, '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '1' THEN
                    INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                    IF ((v.value)::INTEGER & 32) > 0 THEN
                        UPDATE structs.struct SET is_destroyed = 't' WHERE id = split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3);
                    END IF;
                ELSE
                END CASE;
        END IF;

    END IF;
END
$BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                     COST 100;

COMMIT;
