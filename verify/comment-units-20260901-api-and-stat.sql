-- Verify structs-pg:comment-units-20260901-api-and-stat on pg

BEGIN;

    DO $$
    DECLARE
        comment_text text;
    BEGIN
        SELECT col_description('structs.api_leaderboard_player'::regclass,
                               attnum)
          INTO comment_text
          FROM pg_attribute
         WHERE attrelid = 'structs.api_leaderboard_player'::regclass
           AND attname = 'alpha_balance';

        IF comment_text IS NULL OR comment_text NOT LIKE '%ualpha%' THEN
            RAISE EXCEPTION 'expected ualpha comment on api_leaderboard_player.alpha_balance';
        END IF;

        SELECT col_description('structs.stat_load'::regclass, attnum)
          INTO comment_text
          FROM pg_attribute
         WHERE attrelid = 'structs.stat_load'::regclass
           AND attname = 'value';

        IF comment_text IS NULL OR comment_text NOT LIKE '%milliwatt%' THEN
            RAISE EXCEPTION 'expected milliwatt comment on stat_load.value';
        END IF;

        SELECT col_description('structs.api_inventory'::regclass, attnum)
          INTO comment_text
          FROM pg_attribute
         WHERE attrelid = 'structs.api_inventory'::regclass
           AND attname = 'balance';

        IF comment_text IS NULL OR comment_text NOT LIKE '%denom%' THEN
            RAISE EXCEPTION 'expected denom comment on api_inventory.balance';
        END IF;
    END
    $$;

ROLLBACK;
