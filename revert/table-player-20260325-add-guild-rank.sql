-- Revert structs-pg:table-player-20260325-add-guild-rank from pg

BEGIN;

    ALTER TABLE structs.player DROP COLUMN IF EXISTS guild_rank;

COMMIT;
