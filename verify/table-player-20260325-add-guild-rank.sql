-- Verify structs-pg:table-player-20260325-add-guild-rank on pg

BEGIN;

    SELECT guild_rank FROM structs.player WHERE FALSE;

ROLLBACK;
