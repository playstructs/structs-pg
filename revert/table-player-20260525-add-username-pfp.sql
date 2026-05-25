-- Revert structs-pg:table-player-20260525-add-username-pfp from pg

BEGIN;

    CREATE TABLE structs.player_meta (
        id CHARACTER VARYING PRIMARY KEY,
        guild_id CHARACTER VARYING,
        username CHARACTER VARYING,
        pfp CHARACTER VARYING,
        status CHARACTER VARYING,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    INSERT INTO structs.player_meta (
        id,
        guild_id,
        username,
        pfp,
        status,
        created_at,
        updated_at
    )
    SELECT
        id,
        guild_id,
        username,
        pfp,
        '',
        created_at,
        updated_at
    FROM structs.player;

    ALTER TABLE structs.player
        DROP COLUMN IF EXISTS username,
        DROP COLUMN IF EXISTS pfp;

COMMIT;
