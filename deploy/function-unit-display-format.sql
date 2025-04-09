-- Deploy structs-pg:function-unit-display-format to pg

BEGIN;


    CREATE OR REPLACE FUNCTION structs.UNIT_DISPLAY_FORMAT(_amount NUMERIC, _denom TEXT)
      RETURNS TEXT AS
    $BODY$
    DECLARE
        format_amount TEXT;
        format_exp INTEGER;
        format_postfix TEXT;

        current_length INTEGER;

        format_token_big TEXT;
        format_token_small TEXT;
    BEGIN
        IF _denom = 'ualpha' THEN

            current_length := LENGTH(floor(_amount)::CHARACTER VARYING);

            format_exp := CASE
                             WHEN current_length >= 16 THEN 18              -- 'talpha' Tergram
                             WHEN current_length between 10 AND 15 THEN 9   -- 'kalpha' Kilogram
                             WHEN current_length between 6 AND 9 THEN 6     -- 'alpha'  gram
                             WHEN current_length between 3 AND 5 THEN 3     -- 'malpha' milligram
                             WHEN current_length between 0 AND 2 THEN 0     -- 'ualpha' microgram
                        END;


            format_postfix := CASE format_exp
                                  WHEN 18 THEN 'Tg'
                                  WHEN 9 THEN 'Kg'
                                  WHEN 6 THEN 'g'
                                  WHEN 3 THEN 'mg'
                                  WHEN 0 THEN 'μg'
                              END;

            format_amount := ROUND((_amount / (10^format_exp))::NUMERIC,2)::TEXT || format_postfix;

        ELSIF _denom LIKE 'uguild%' THEN
            current_length := LENGTH(floor(_amount)::CHARACTER VARYING);

            SELECT guild_meta.denom->>'0', guild_meta.denom->>'6' INTO format_token_small, format_token_big FROM structs.guild_meta WHERE guild_meta.id = trim(_denom,'uguild.') ;

            format_exp := CASE
                            WHEN current_length >= 6 THEN 6              -- guild.
                            WHEN current_length between 0 AND 5 THEN 0   -- uguild.
                          END;


            format_postfix := CASE format_exp
                                  WHEN 6 THEN COALESCE (format_token_big, SUBSTRING(_denom, 2, length(_denom)-1))
                                  WHEN 0 THEN COALESCE (format_token_small,_denom)
                                 END;

            format_amount := ROUND((_amount / (10^format_exp))::NUMERIC,2)::TEXT || format_postfix;

        ELSIF _denom = 'milliwatt' THEN

            current_length := LENGTH(floor(_amount)::CHARACTER VARYING);

            format_exp := CASE
                           WHEN current_length >= 16 THEN 18            -- terawatt
                           WHEN current_length between 10 AND 15 THEN 9 -- megawatt
                           WHEN current_length between 6 AND 9 THEN 6   -- kilowatt
                           WHEN current_length between 3 AND 5 THEN 3   -- watt
                           WHEN current_length between 0 AND 2 THEN 0   -- milliwatt
                          END;


            format_postfix := CASE format_exp
                                  WHEN 18 THEN 'TW'
                                  WHEN 9 THEN 'MW'
                                  WHEN 6 THEN 'KW'
                                  WHEN 3 THEN 'W'
                                  WHEN 0 THEN 'mW'
                END;

            format_amount := ROUND((_amount / (10^format_exp))::NUMERIC,2)::TEXT || format_postfix;

        ELSIF _denom = 'ore' THEN
            current_length := LENGTH(floor(_amount)::CHARACTER VARYING);

            format_exp := CASE
                           WHEN current_length >= 12 THEN 18            -- teragram
                           WHEN current_length between 4 AND 11 THEN 3  -- kilogram
                           WHEN current_length between 0 AND 3 THEN 0   -- gram
                          END;

            format_postfix := CASE format_exp
                                  WHEN 12 THEN 'Tg'
                                  WHEN 3 THEN 'Kg'
                                  WHEN 0 THEN 'g'
                END;

            format_amount := ROUND((_amount / (10^format_exp))::NUMERIC,2)::TEXT || format_postfix;
        END IF;

        RETURN format_amount;
    END
    $BODY$
      LANGUAGE plpgsql STABLE
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

