-- Deploy structs-pg:table-permission-guild-rank to pg

BEGIN;

    CREATE TABLE structs.permission_guild_rank (
        object_id   CHARACTER VARYING,
        guild_id    CHARACTER VARYING,
        permission  BIGINT,
        rank        BIGINT,
        updated_at  TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (object_id, guild_id, permission)
    );

COMMIT;
