-- Verify structs-pg:table-planet-attribute-20260904-repair-ore-clock-labels on pg

BEGIN;

    DO $$
    DECLARE
        remaining bigint;
    BEGIN
        SELECT count(*) INTO remaining
          FROM structs.planet_attribute
         WHERE attribute_type IS NULL
           AND split_part(id, '-', 1) IN ('11', '12', '13', '14', '15');

        IF remaining <> 0 THEN
            RAISE EXCEPTION
                'expected 0 unnamed planet_attribute rows for prefixes 11-15, found %',
                remaining;
        END IF;
    END
    $$;

ROLLBACK;
