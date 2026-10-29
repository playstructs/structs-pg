-- Revert structs-pg:table-ranks-20261029-uint64 from pg
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.player WHERE guild_rank > 9223372036854775807)
       OR EXISTS (SELECT 1 FROM structs.guild WHERE entry_rank > 9223372036854775807)
       OR EXISTS (SELECT 1 FROM structs.permission_guild_rank WHERE rank > 9223372036854775807) THEN
        RAISE EXCEPTION 'rank exceeds bigint; retain unsigned schema or restore a verified checkpoint';
    END IF;
END $$;
ALTER TABLE structs.player DROP CONSTRAINT player_guild_rank_uint64,
    ALTER COLUMN guild_rank TYPE BIGINT;
ALTER TABLE structs.guild DROP CONSTRAINT guild_entry_rank_uint64,
    ALTER COLUMN entry_rank TYPE BIGINT;
ALTER TABLE structs.permission_guild_rank DROP CONSTRAINT permission_guild_rank_uint64,
    ALTER COLUMN rank TYPE BIGINT;
COMMIT;
