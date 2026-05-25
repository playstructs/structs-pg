-- Deploy structs-pg:table-guild-20260525-add-name-pfp to pg
--
-- Chain UGC (name / pfp) belongs on structs.guild.

BEGIN;

    ALTER TABLE structs.guild
        ADD COLUMN name CHARACTER VARYING,
        ADD COLUMN pfp  CHARACTER VARYING;

    UPDATE structs.guild g
       SET name = gm.name,
           pfp  = gm.pfp
      FROM structs.guild_meta gm
     WHERE g.id = gm.id;

COMMIT;
