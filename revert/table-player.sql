-- Revert structs-pg:table-player from pg

BEGIN;

DROP TABLE structs.player;

DROP TABLE structs.player_meta;

DROP TABLE structs.player_pending;

DROP TABLE structs.player_address;

DROP TABLE structs.player_address_activity;

DROP TABLE structs.player_address_meta;

DROP TABLE structs.player_address_pending;

COMMIT;
