-- Deploy structs-pg:table-guild-meta-20260427-add-pfp to pg

BEGIN;

    ALTER TABLE structs.guild_meta
        ADD COLUMN pfp CHARACTER VARYING;

COMMIT;
