-- Verify structs-pg:table-planet-attribute-20260824-copy-ore-clocks-from-struct on pg

BEGIN;

    -- Backfill is idempotent: leftover struct clocks either have a matching
    -- planet row, or a planet row already existed (ON CONFLICT DO NOTHING).
    DO $$
    DECLARE
        missing_mine integer;
        missing_refine integer;
    BEGIN
        SELECT COUNT(*) INTO missing_mine
        FROM (
            SELECT struct.location_id
            FROM structs.struct
                INNER JOIN structs.struct_type ON struct_type.id = struct.type
                INNER JOIN structs.struct_attribute
                    ON struct_attribute.id = '3-' || struct.id
                   AND struct_attribute.val > 0
                INNER JOIN structs.struct_attribute AS status_attr
                    ON status_attr.object_id = struct.id
                   AND status_attr.attribute_type = 'status'
            WHERE
                struct.location_type = 'planet'
                AND struct.location_id IS NOT NULL
                AND struct.location_id <> ''
                AND struct_type.planetary_mining = 'oreMiningRig'
                AND (status_attr.val & 4) > 0
                AND (status_attr.val & 32) = 0
            GROUP BY struct.location_id
        ) src
        WHERE NOT EXISTS (
            SELECT 1 FROM structs.planet_attribute
            WHERE planet_attribute.id = '12-' || src.location_id
        );

        SELECT COUNT(*) INTO missing_refine
        FROM (
            SELECT struct.location_id
            FROM structs.struct
                INNER JOIN structs.struct_type ON struct_type.id = struct.type
                INNER JOIN structs.struct_attribute
                    ON struct_attribute.id = '4-' || struct.id
                   AND struct_attribute.val > 0
                INNER JOIN structs.struct_attribute AS status_attr
                    ON status_attr.object_id = struct.id
                   AND status_attr.attribute_type = 'status'
            WHERE
                struct.location_type = 'planet'
                AND struct.location_id IS NOT NULL
                AND struct.location_id <> ''
                AND struct_type.planetary_refinery = 'oreRefinery'
                AND (status_attr.val & 4) > 0
                AND (status_attr.val & 32) = 0
            GROUP BY struct.location_id
        ) src
        WHERE NOT EXISTS (
            SELECT 1 FROM structs.planet_attribute
            WHERE planet_attribute.id = '13-' || src.location_id
        );

        IF missing_mine > 0 THEN
            RAISE EXCEPTION 'planet ore mine clocks missing for % planets with leftover struct clocks', missing_mine;
        END IF;
        IF missing_refine > 0 THEN
            RAISE EXCEPTION 'planet ore refine clocks missing for % planets with leftover struct clocks', missing_refine;
        END IF;
    END $$;

ROLLBACK;
