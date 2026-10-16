-- Revert structs-pg:table-mini-game-progress-20261016 from pg

BEGIN;

    DROP TABLE IF EXISTS structs.mini_game_progress;

COMMIT;
