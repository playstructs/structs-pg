-- Revert structs-pg:table-guild-meta-20260525-drop-pfp from pg

BEGIN;

    ALTER TABLE structs.guild_meta
        ADD COLUMN pfp CHARACTER VARYING;

    UPDATE structs.guild_meta gm
       SET pfp = g.pfp
      FROM structs.guild g
     WHERE g.id = gm.id;

COMMIT;
