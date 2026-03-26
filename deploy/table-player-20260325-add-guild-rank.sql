-- Deploy structs-pg:table-player-20260325-add-guild-rank to pg

BEGIN;

    ALTER TABLE structs.player ADD COLUMN guild_rank BIGINT;

COMMIT;
