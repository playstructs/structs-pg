-- Revert structs-pg:view-player-20260525-inline-ugc from pg

BEGIN;

    DROP VIEW IF EXISTS view.player_inventory CASCADE;
    DROP VIEW IF EXISTS view.player CASCADE;

COMMIT;
