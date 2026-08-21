-- Deploy structs-pg:table-api-read-support-20260820-indexes to pg
--
-- Covers agreement windows, raid cursors, inventory ownership, guild member
-- counts, and normalized prefix resolution.

BEGIN;

    CREATE INDEX agreement_provider_start_end_idx
        ON structs.agreement (provider_id, start_block, end_block);

    CREATE INDEX planet_raid_updated_planet_fleet_idx
        ON structs.planet_raid (updated_at DESC, planet_id, fleet_id);

    CREATE INDEX player_address_player_id_idx
        ON structs.player_address (player_id);

    CREATE INDEX player_guild_id_idx
        ON structs.player (guild_id);

    CREATE INDEX player_username_lower_idx
        ON structs.player (lower(username) text_pattern_ops);

    CREATE INDEX guild_name_lower_idx
        ON structs.guild (lower(name) text_pattern_ops);

COMMIT;
