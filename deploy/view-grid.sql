-- Deploy structs-pg:view-grid to pg

BEGIN;

CREATE OR REPLACE VIEW view.grid AS
        SELECT
            id as attribute_id,

            CASE split_part(id, '-',1)
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
                ELSE 'error'
            END as attribute_type,

            CASE split_part(id, '-', 2)
                WHEN '0' THEN 'guild'
                WHEN '1' THEN 'player'
                WHEN '2' THEN 'planet'
                WHEN '3' THEN 'reactor'
                WHEN '4' THEN 'substation'
                WHEN '5' THEN 'struct'
                WHEN '6' THEN 'allocation'
                WHEN '7' THEN 'infusion'
                WHEN '8' THEN 'address'
            END as object_type,

            split_part(id,'-',3) as object_index,

            split_part(id,'-',2) || '-' || split_part(id,'-',3) as object_id,

            val as value,

            updated_at
        FROM structs.grid;

COMMIT;
