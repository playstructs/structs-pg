-- Revert structs-pg:table-player from pg

BEGIN;

DROP TABLE structs.player;

DROP TABLE structs.player_meta;

DROP TABLE structs.player_pending;

DROP TABLE structs.player_address;

COMMIT;
