-- Deploy structs-pg:role-structs-webapp-20261016-mini-game-progress to pg
--
-- The webapp records and updates a player's current mini-game score.

BEGIN;

    GRANT SELECT, INSERT, UPDATE, DELETE
        ON structs.mini_game_progress
        TO structs_webapp;

COMMIT;
