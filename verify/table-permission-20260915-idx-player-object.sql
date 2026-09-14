-- Verify structs-pg:table-permission-20260915-idx-player-object on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regclass('structs.permission_player_id_idx') IS NULL
           OR to_regclass('structs.permission_object_id_idx') IS NULL THEN
            RAISE EXCEPTION 'expected permission_player_id_idx and permission_object_id_idx';
        END IF;
    END
    $$;

ROLLBACK;
