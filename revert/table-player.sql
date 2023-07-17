-- Revert structs-pg:table-player from pg

BEGIN;

DROP TABLE structs.player;

COMMIT;
