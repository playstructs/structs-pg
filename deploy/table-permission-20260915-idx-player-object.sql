-- Deploy structs-pg:table-permission-20260915-idx-player-object to pg
--
-- structs.permission (236k rows) had only its primary key on the composite
-- text id. view.permission_player / view.permission_address and the webapp
-- filter by player_id and object_id; every such read was a sequential scan
-- (21k scans, 3.8B tuples read when this was written).

BEGIN;

    CREATE INDEX permission_player_id_idx ON structs.permission (player_id);
    CREATE INDEX permission_object_id_idx ON structs.permission (object_id);

COMMIT;
