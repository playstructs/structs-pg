-- Deploy structs-pg:function-flat-to-ambits to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.flag_to_ambits(flag_value INTEGER)
        RETURNS JSONB AS $$
    DECLARE
        result TEXT[] := ARRAY[]::TEXT[];
    BEGIN
        -- Bit 5: local
        IF (flag_value & (1 << 5)) != 0 THEN
            result := array_append(result, 'local');
        END IF;

        -- Bit 4: space
        IF (flag_value & (1 << 4)) != 0 THEN
            result := array_append(result, 'space');
        END IF;

        -- Bit 3: air
        IF (flag_value & (1 << 3)) != 0 THEN
            result := array_append(result, 'air');
        END IF;

        -- Bit 2: land
        IF (flag_value & (1 << 2)) != 0 THEN
            result := array_append(result, 'land');
        END IF;

        -- Bit 1: water
        IF (flag_value & (1 << 1)) != 0 THEN
            result := array_append(result, 'water');
        END IF;

        RETURN to_jsonb(result);
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;



COMMIT;

