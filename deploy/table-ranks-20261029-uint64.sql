-- Deploy structs-pg:table-ranks-20261029-uint64 to pg
BEGIN;
-- Keep existing names/nullability/grants. Unscaled NUMERIC rejects fractions
-- through the constraint instead of rounding them before validation.
ALTER TABLE structs.player ALTER COLUMN guild_rank TYPE NUMERIC,
    ADD CONSTRAINT player_guild_rank_uint64 CHECK (guild_rank >= 0 AND guild_rank <= 18446744073709551615 AND guild_rank = trunc(guild_rank));
ALTER TABLE structs.guild ALTER COLUMN entry_rank TYPE NUMERIC,
    ADD CONSTRAINT guild_entry_rank_uint64 CHECK (entry_rank >= 0 AND entry_rank <= 18446744073709551615 AND entry_rank = trunc(entry_rank));
ALTER TABLE structs.permission_guild_rank ALTER COLUMN rank TYPE NUMERIC,
    ADD CONSTRAINT permission_guild_rank_uint64 CHECK (rank >= 0 AND rank <= 18446744073709551615 AND rank = trunc(rank));
COMMIT;
