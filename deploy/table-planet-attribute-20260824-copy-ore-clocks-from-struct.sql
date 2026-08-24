-- Deploy structs-pg:table-planet-attribute-20260824-copy-ore-clocks-from-struct to pg
--
-- One-shot backfill for databases that still have pre-v0.21.0 struct ore
-- clocks (struct_attribute 3-/4-) after the views switched to planet
-- attributes 12-/13-.
--
-- Matches structsd MigrateOreClocksToPlanet:
--   * only planet-located, online, not-destroyed mining/refining structs
--   * planet clock = MIN(nonzero struct clock) for that planet
--   * planet quantity = COUNT of those online structs
--
-- ON CONFLICT DO NOTHING: if sync-state already indexed the chain upgrade
-- (planet rows exist), leave them alone. Zero-valued struct clocks were
-- already deleted from struct_attribute and are not copied.

BEGIN;

    -- Shared mine clock (12-) from struct attr 3-
    INSERT INTO structs.planet_attribute (
        id, object_id, object_type, attribute_type, val, updated_at
    )
    SELECT
        '12-' || struct.location_id,
        struct.location_id,
        'planet',
        'blockStartOreMine',
        MIN(struct_attribute.val),
        NOW()
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
    ON CONFLICT (id) DO NOTHING;

    -- Shared refine clock (13-) from struct attr 4-
    INSERT INTO structs.planet_attribute (
        id, object_id, object_type, attribute_type, val, updated_at
    )
    SELECT
        '13-' || struct.location_id,
        struct.location_id,
        'planet',
        'blockStartOreRefine',
        MIN(struct_attribute.val),
        NOW()
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
    ON CONFLICT (id) DO NOTHING;

    -- Online mining rig count (14-)
    INSERT INTO structs.planet_attribute (
        id, object_id, object_type, attribute_type, val, updated_at
    )
    SELECT
        '14-' || struct.location_id,
        struct.location_id,
        'planet',
        'oreMiningActiveQuantity',
        COUNT(*)::INTEGER,
        NOW()
    FROM structs.struct
        INNER JOIN structs.struct_type ON struct_type.id = struct.type
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
    HAVING COUNT(*) > 0
    ON CONFLICT (id) DO NOTHING;

    -- Online refinery count (15-)
    INSERT INTO structs.planet_attribute (
        id, object_id, object_type, attribute_type, val, updated_at
    )
    SELECT
        '15-' || struct.location_id,
        struct.location_id,
        'planet',
        'oreRefiningActiveQuantity',
        COUNT(*)::INTEGER,
        NOW()
    FROM structs.struct
        INNER JOIN structs.struct_type ON struct_type.id = struct.type
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
    HAVING COUNT(*) > 0
    ON CONFLICT (id) DO NOTHING;

COMMIT;
