-- Revert structs-pg:table-player-meta-20260427-collapse-pk from pg
--
-- Restores the (id, guild_id) composite primary key. Deduped historical
-- rows are NOT recreated; they were stale by definition.

BEGIN;

    ALTER TABLE structs.player_meta
        DROP CONSTRAINT player_meta_pkey;

    ALTER TABLE structs.player_meta
        ADD PRIMARY KEY (id, guild_id);

COMMIT;
