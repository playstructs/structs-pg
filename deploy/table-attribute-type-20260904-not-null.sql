-- Deploy structs-pg:table-attribute-type-20260904-not-null to pg
--
-- Guard against another unlabeled-attribute hole: require attribute_type on
-- planet_attribute, struct_attribute, and grid.
--
-- DEPLOY ORDER (from Structs.app handoff 2026-09-04):
--   1. Production sync-state at eb30ede or later (labels 11–15)
--   2. table-planet-attribute-20260904-repair-ore-clock-labels
--   3. This change
--
-- Applying NOT NULL while an old writer still inserts types 11–15 as NULL
-- will fail those inserts. Do not deploy this change until the writer is
-- current.
--
-- Before ALTER, backfill any remaining NULL labels from known id prefixes
-- so historical rows do not block the constraint.

BEGIN;

    -- Re-apply ore-clock label repair (idempotent)
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

    -- Known planet attribute prefixes 0–10 (and 11–15 above)
    UPDATE structs.planet_attribute
    SET attribute_type = CASE split_part(id, '-', 1)
            WHEN '0' THEN 'planetaryShield'
            WHEN '1' THEN 'repairNetworkQuantity'
            WHEN '2' THEN 'defensiveCannonQuantity'
            WHEN '3' THEN 'coordinatedGlobalShieldNetworkQuantity'
            WHEN '4' THEN 'lowOrbitBallisticsInterceptorNetworkQuantity'
            WHEN '5' THEN 'advancedLowOrbitBallisticsInterceptorNetworkQuantity'
            WHEN '6' THEN 'lowOrbitBallisticsInterceptorNetworkSuccessRateNumerator'
            WHEN '7' THEN 'lowOrbitBallisticsInterceptorNetworkSuccessRateDenominator'
            WHEN '8' THEN 'orbitalJammingStationQuantity'
            WHEN '9' THEN 'advancedOrbitalJammingStationQuantity'
            WHEN '10' THEN 'blockStartRaid'
        END
    WHERE attribute_type IS NULL
      AND split_part(id, '-', 1) IN (
          '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'
      );

    UPDATE structs.struct_attribute
    SET attribute_type = CASE split_part(id, '-', 1)
            WHEN '0' THEN 'health'
            WHEN '1' THEN 'status'
            WHEN '2' THEN 'blockStartBuild'
            WHEN '3' THEN 'blockStartOreMine'
            WHEN '4' THEN 'blockStartOreRefine'
            WHEN '5' THEN 'protectedStructIndex'
            WHEN '6' THEN 'typeCount'
        END
    WHERE attribute_type IS NULL
      AND split_part(id, '-', 1) IN ('0', '1', '2', '3', '4', '5', '6');

    UPDATE structs.grid
    SET attribute_type = CASE split_part(id, '-', 1)
            WHEN '0' THEN 'ore'
            WHEN '1' THEN 'fuel'
            WHEN '2' THEN 'capacity'
            WHEN '3' THEN 'load'
            WHEN '4' THEN 'structsLoad'
            WHEN '5' THEN 'power'
            WHEN '6' THEN 'connectionCapacity'
            WHEN '7' THEN 'connectionCount'
        END
    WHERE attribute_type IS NULL
      AND split_part(id, '-', 1) IN ('0', '1', '2', '3', '4', '5', '6', '7');

    DO $$
    DECLARE
        remaining bigint;
    BEGIN
        SELECT count(*) INTO remaining FROM structs.planet_attribute WHERE attribute_type IS NULL;
        IF remaining <> 0 THEN
            RAISE EXCEPTION
                'cannot set planet_attribute.attribute_type NOT NULL: % unlabeled rows remain (deploy sync-state eb30ede+ and repair first)',
                remaining;
        END IF;

        SELECT count(*) INTO remaining FROM structs.struct_attribute WHERE attribute_type IS NULL;
        IF remaining <> 0 THEN
            RAISE EXCEPTION
                'cannot set struct_attribute.attribute_type NOT NULL: % unlabeled rows remain',
                remaining;
        END IF;

        SELECT count(*) INTO remaining FROM structs.grid WHERE attribute_type IS NULL;
        IF remaining <> 0 THEN
            RAISE EXCEPTION
                'cannot set grid.attribute_type NOT NULL: % unlabeled rows remain',
                remaining;
        END IF;
    END
    $$;

    ALTER TABLE structs.planet_attribute
        ALTER COLUMN attribute_type SET NOT NULL;

    ALTER TABLE structs.struct_attribute
        ALTER COLUMN attribute_type SET NOT NULL;

    ALTER TABLE structs.grid
        ALTER COLUMN attribute_type SET NOT NULL;

COMMIT;
