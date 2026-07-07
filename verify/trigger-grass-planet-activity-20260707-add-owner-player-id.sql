-- Verify structs-pg:trigger-grass-planet-activity-20260707-add-owner-player-id on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.planet_activity_notify()') IS NULL THEN
            RAISE EXCEPTION 'expected structs.PLANET_ACTIVITY_NOTIFY() to exist';
        END IF;

        IF pg_get_functiondef(to_regprocedure('structs.planet_activity_notify()')) NOT LIKE '%|| NEW.planet_id || ''.'' || _player_id%' THEN
            RAISE EXCEPTION 'expected structs.PLANET_ACTIVITY_NOTIFY() subject to append the owning player id';
        END IF;

        IF pg_get_functiondef(to_regprocedure('structs.planet_activity_notify()')) NOT LIKE '%''player_id'', _player_id%' THEN
            RAISE EXCEPTION 'expected structs.PLANET_ACTIVITY_NOTIFY() payload to include player_id';
        END IF;
    END
    $$;

ROLLBACK;
