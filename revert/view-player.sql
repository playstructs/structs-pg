-- Revert structs-pg:view-player from pg

BEGIN;

DROP VIEW view.player;

COMMIT;
