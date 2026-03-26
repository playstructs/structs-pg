-- Revert structs-pg:table-permission-guild-rank from pg

BEGIN;

    DROP TABLE IF EXISTS structs.permission_guild_rank;

COMMIT;
