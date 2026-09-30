-- Revert structs-pg:function-unit-display-format-20260930-zero-display-unit from pg
--
-- Restores UNIT_DISPLAY_FORMAT from function-unit-display-format-20260930-fix-ladders.

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

        _denom := REPLACE(_denom, '.infused','');
        _denom := REPLACE(_denom, '.defusing','');

        current_length := LENGTH(floor(abs(_amount))::CHARACTER VARYING);

        IF _denom = 'ualpha' THEN

            format_exp := CASE
                             WHEN current_length >= 18 THEN 18              -- 'talpha' Teragram
                             WHEN current_length between 10 AND 17 THEN 9   -- 'kalpha' Kilogram
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

        ELSIF _denom LIKE 'uguild%' THEN

            SELECT guild_meta.denom->>'0', guild_meta.denom->>'6' INTO format_token_small, format_token_big FROM structs.guild_meta WHERE guild_meta.id = trim(_denom,'uguild.') ;

            format_exp := CASE
                            WHEN current_length >= 6 THEN 6              -- guild.
                            WHEN current_length between 0 AND 5 THEN 0   -- uguild.
                          END;


            format_postfix := CASE format_exp
                                  WHEN 6 THEN COALESCE (format_token_big, SUBSTRING(_denom, 2, length(_denom)-1))
                                  WHEN 0 THEN COALESCE (format_token_small,_denom)
                                 END;

        ELSIF _denom = 'milliwatt' THEN

            format_exp := CASE
                           WHEN current_length >= 16 THEN 15            -- terawatt
                           WHEN current_length between 10 AND 15 THEN 9 -- megawatt
                           WHEN current_length between 6 AND 9 THEN 6   -- kilowatt
                           WHEN current_length between 3 AND 5 THEN 3   -- watt
                           WHEN current_length between 0 AND 2 THEN 0   -- milliwatt
                          END;


            format_postfix := CASE format_exp
                                  WHEN 15 THEN 'TW'
                                  WHEN 9 THEN 'MW'
                                  WHEN 6 THEN 'KW'
                                  WHEN 3 THEN 'W'
                                  WHEN 0 THEN 'mW'
                END;

        ELSIF _denom = 'ore' THEN

            format_exp := CASE
                           WHEN current_length >= 12 THEN 12            -- teragram
                           WHEN current_length between 4 AND 11 THEN 3  -- kilogram
                           WHEN current_length between 0 AND 3 THEN 0   -- gram
                          END;

            format_postfix := CASE format_exp
                                  WHEN 12 THEN 'Tg'
                                  WHEN 3 THEN 'Kg'
                                  WHEN 0 THEN 'g'
                END;

        ELSE
            RETURN NULL;
        END IF;

        format_amount := trim_scale(ROUND(_amount / (10::NUMERIC ^ format_exp), 2))::TEXT || format_postfix;

        RETURN format_amount;
    END
    $BODY$
      LANGUAGE plpgsql STABLE
      COST 100;

COMMIT;
