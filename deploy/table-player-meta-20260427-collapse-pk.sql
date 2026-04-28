-- Deploy structs-pg:table-player-meta-20260427-collapse-pk to pg
--
-- Chain UGC (player name / pfp) is global per player, but player_meta was
-- previously keyed by (id, guild_id) which allowed historical rows to
-- accumulate as players moved between guilds. Collapse to one row per
-- player by:
--   1. Deleting rows whose guild_id no longer matches the player's current guild
--   2. Deleting rows where the player no longer exists at all
--   3. Swapping the PK from (id, guild_id) to (id)
--
-- The guild_id column is RETAINED:
--   - structs.PLAYER_META_NOTIFY reads NEW.guild_id to build its grass subject
--   - cache.handle_event_player keeps it in sync with the player's current guild

BEGIN;

    DELETE FROM structs.player_meta pm
    USING structs.player p
    WHERE pm.id = p.id
      AND pm.guild_id IS DISTINCT FROM p.guild_id;

    DELETE FROM structs.player_meta pm
    WHERE NOT EXISTS (
        SELECT 1 FROM structs.player p WHERE p.id = pm.id
    );

    ALTER TABLE structs.player_meta
        DROP CONSTRAINT player_meta_pkey;

    ALTER TABLE structs.player_meta
        ADD PRIMARY KEY (id);

COMMIT;
