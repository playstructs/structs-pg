-- Revert structs-pg:table-permission-20260915-idx-player-object from pg

BEGIN;

    DROP INDEX IF EXISTS structs.permission_player_id_idx;
    DROP INDEX IF EXISTS structs.permission_object_id_idx;

COMMIT;
