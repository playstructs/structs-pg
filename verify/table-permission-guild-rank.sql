-- Verify structs-pg:table-permission-guild-rank on pg

BEGIN;

    SELECT object_id, guild_id, permission, rank, updated_at
    FROM structs.permission_guild_rank
    WHERE FALSE;

ROLLBACK;
