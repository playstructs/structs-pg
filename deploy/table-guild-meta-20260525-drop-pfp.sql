-- Deploy structs-pg:table-guild-meta-20260525-drop-pfp to pg
--
-- pfp is chain UGC on structs.guild; remove from guild_meta.

BEGIN;

    ALTER TABLE structs.guild_meta
        DROP COLUMN pfp;

COMMIT;
