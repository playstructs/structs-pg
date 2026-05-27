-- Deploy structs-pg:table-player-20260525-add-username-pfp to pg
--
-- Chain UGC (username / pfp) belongs on structs.player. Retire player_meta.

BEGIN;

    ALTER TABLE structs.player
        ADD COLUMN username CHARACTER VARYING,
        ADD COLUMN pfp       CHARACTER VARYING;

    UPDATE structs.player p
       SET username = pm.username,
           pfp      = pm.pfp
      FROM structs.player_meta pm
     WHERE p.id = pm.id;

    DROP TABLE structs.player_meta CASCADE;

COMMIT;
