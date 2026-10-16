-- Deploy structs-pg:table-mini-game-progress-20261016 to pg
--
-- One current score per player, interface, and game. The webapp upserts
-- this row as a player plays; created_at is the first play and updated_at
-- moves on each new score.

BEGIN;

    CREATE TABLE structs.mini_game_progress (
        player_id      CHARACTER VARYING NOT NULL,
        interface_name CHARACTER VARYING NOT NULL,
        game_name      CHARACTER VARYING NOT NULL,
        score          INTEGER NOT NULL,
        created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (player_id, interface_name, game_name)
    );

COMMIT;
