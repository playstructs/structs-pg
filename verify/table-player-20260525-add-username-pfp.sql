-- Verify structs-pg:table-player-20260525-add-username-pfp on pg

BEGIN;

    SELECT username, pfp FROM structs.player WHERE FALSE;

    DO $$
    BEGIN
        IF to_regclass('structs.player_meta') IS NOT NULL THEN
            RAISE EXCEPTION 'expected structs.player_meta to be dropped';
        END IF;
    END
    $$;

ROLLBACK;
