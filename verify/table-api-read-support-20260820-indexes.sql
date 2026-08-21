-- Verify structs-pg:table-api-read-support-20260820-indexes on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.agreement_provider_start_end_idx')) INTO def;
        IF def IS NULL OR def NOT LIKE '%(provider_id, start_block, end_block)%' THEN
            RAISE EXCEPTION 'agreement provider index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.planet_raid_updated_planet_fleet_idx')) INTO def;
        IF def IS NULL OR def NOT LIKE '%(updated_at DESC, planet_id, fleet_id)%' THEN
            RAISE EXCEPTION 'planet raid cursor index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.player_address_player_id_idx')) INTO def;
        IF def IS NULL OR def NOT LIKE '%(player_id)%' THEN
            RAISE EXCEPTION 'player address owner index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.player_guild_id_idx')) INTO def;
        IF def IS NULL OR def NOT LIKE '%(guild_id)%' THEN
            RAISE EXCEPTION 'player guild index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.player_username_lower_idx')) INTO def;
        IF def IS NULL OR def NOT ILIKE '%lower%username%text_pattern_ops%' THEN
            RAISE EXCEPTION 'player username prefix index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.guild_name_lower_idx')) INTO def;
        IF def IS NULL OR def NOT ILIKE '%lower%name%text_pattern_ops%' THEN
            RAISE EXCEPTION 'guild name prefix index unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
