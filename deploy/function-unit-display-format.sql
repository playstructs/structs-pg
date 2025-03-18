-- Deploy structs-pg:function-unit-display-format to pg

BEGIN;



    CREATE OR REPLACE FUNCTION structs.UNIT_DISPLAY_FORMAT(amount NUMERIC, denom TEXT, unit TEXT)
      RETURNS TEXT AS
    $BODY$
    DECLARE
        format_amount TEXT;
        format_exp INTEGER;

        current_length INTEGER;
    BEGIN
        IF denom = 'ualpha' THEN

            current_length := LENGTH(floor(amount)::CHARACTER VARYING);

            format_exp := CASE unit
                    WHEN 'talpha' THEN 18
                    WHEN 'teragram' THEN 18

                    WHEN 'kalpha' THEN 9
                    WHEN 'kilogram' THEN 9

                    WHEN 'alpha' THEN 6
                    WHEN 'gram' THEN 6

                    WHEN 'malpha' THEN 3
                    WHEN 'milligram' THEN 3

                    WHEN 'ualpha' THEN 0
                    WHEN 'microgram' THEN 0

                    WHEN 'auto' THEN
                        (CASE
                             WHEN current_length > 16 THEN 18
                             WHEN current_length between 9 AND 16 THEN 9
                             WHEN current_length between 6 AND 9 THEN 6
                             WHEN current_length between 3 AND 6 THEN 3
                             WHEN current_length between 0 AND 3 THEN 0
                            END
                            )

                    END;
            format_amount := floor(amount / format_exp);

        ELSIF denom LIKE 'uguild%' THEN
            format_amount := floor(amount / 1000000);

        ELSIF denom = 'milliwatt' THEN
            format_amount := floor(amount / 1000);

        ELSIF denom = 'ore' THEN
            format_amount := amount;
        END IF;

        RETURN format_amount;
    END
    $BODY$
      LANGUAGE plpgsql IMMUTABLE
      COST 100;


    CREATE OR REPLACE FUNCTION structs.UNIT_LEGACY_FORMAT(amount NUMERIC, denom TEXT)
        RETURNS NUMERIC AS
    $BODY$
    DECLARE
        legacy_amount NUMERIC;
    BEGIN
        IF denom = 'ualpha' THEN
            legacy_amount := floor(amount / 1000000);

        ELSIF denom LIKE 'uguild%' THEN
            legacy_amount := floor(amount / 1000000);

        ELSIF denom = 'milliwatt' THEN
            legacy_amount := floor(amount / 1000);

        ELSIF denom = 'ore' THEN
            legacy_amount := amount;
        END IF;

        RETURN legacy_amount;
    END
    $BODY$
        LANGUAGE plpgsql IMMUTABLE COST 100;


COMMIT;

