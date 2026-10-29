-- Verify structs-pg:table-ranks-20261029-uint64 on pg
BEGIN;
DO $$
DECLARE spec RECORD;
BEGIN
    FOR spec IN SELECT * FROM (VALUES
        ('player','guild_rank','player_guild_rank_uint64'),
        ('guild','entry_rank','guild_entry_rank_uint64'),
        ('permission_guild_rank','rank','permission_guild_rank_uint64')
    ) AS required(rel,col,con) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_attribute
            WHERE attrelid=('structs.'||spec.rel)::regclass AND attname=spec.col
              AND atttypid='numeric'::regtype AND atttypmod=-1 AND NOT attisdropped)
        OR NOT EXISTS (SELECT 1 FROM pg_constraint
            WHERE conrelid=('structs.'||spec.rel)::regclass AND conname=spec.con AND convalidated) THEN
            RAISE EXCEPTION 'missing exact unsigned rank contract %.%',spec.rel,spec.col;
        END IF;
    END LOOP;
END $$;
ROLLBACK;
