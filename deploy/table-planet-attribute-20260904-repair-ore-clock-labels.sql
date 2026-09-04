-- Deploy structs-pg:table-planet-attribute-20260904-repair-ore-clock-labels to pg
--
-- Older sync-state / cache writers indexed planet attribute types 11–15 with
-- attribute_type NULL (label map stopped at 10). ON CONFLICT only rewrites
-- val, so those rows never self-heal. Idempotent label repair for API /
-- GRASS / type-filtered reads.
--
-- Stored string keys (not proto enum names planetBlockStartOreMine /
-- planetBlockStartOreRefine). Safe to run before or after sync-state eb30ede+.

BEGIN;

    UPDATE structs.planet_attribute
    SET attribute_type = CASE split_part(id, '-', 1)
            WHEN '11' THEN 'blockRaiderArrived'
            WHEN '12' THEN 'blockStartOreMine'
            WHEN '13' THEN 'blockStartOreRefine'
            WHEN '14' THEN 'oreMiningActiveQuantity'
            WHEN '15' THEN 'oreRefiningActiveQuantity'
        END
    WHERE attribute_type IS NULL
      AND split_part(id, '-', 1) IN ('11', '12', '13', '14', '15');

COMMIT;
