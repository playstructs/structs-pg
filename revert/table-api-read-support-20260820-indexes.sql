-- Revert structs-pg:table-api-read-support-20260820-indexes from pg

BEGIN;

    DROP INDEX IF EXISTS structs.guild_name_lower_idx;
    DROP INDEX IF EXISTS structs.player_username_lower_idx;
    DROP INDEX IF EXISTS structs.player_guild_id_idx;
    DROP INDEX IF EXISTS structs.player_address_player_id_idx;
    DROP INDEX IF EXISTS structs.planet_raid_updated_planet_fleet_idx;
    DROP INDEX IF EXISTS structs.agreement_provider_start_end_idx;

COMMIT;
