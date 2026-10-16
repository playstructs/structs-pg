-- Revert structs-pg:role-structs-webapp-20261016-mini-game-progress from pg

BEGIN;

    REVOKE SELECT, INSERT, UPDATE, DELETE
        ON structs.mini_game_progress
        FROM structs_webapp;

COMMIT;
