-- Verify structs-pg:trigger-grass-grid-20260707-add-owner-player-id on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.grid_notify()') IS NULL THEN
            RAISE EXCEPTION 'expected structs.GRID_NOTIFY() to exist';
        END IF;

        IF pg_get_functiondef(to_regprocedure('structs.grid_notify()')) NOT LIKE '%|| NEW.object_id || ''.'' || _player_id%' THEN
            RAISE EXCEPTION 'expected structs.GRID_NOTIFY() subject to append the owning player id';
        END IF;

        IF pg_get_functiondef(to_regprocedure('structs.grid_notify()')) NOT LIKE '%''player_id'', _player_id%' THEN
            RAISE EXCEPTION 'expected structs.GRID_NOTIFY() payload to include player_id';
        END IF;
    END
    $$;

ROLLBACK;
