-- Verify structs-pg:table-structs-api-read-20260820-current-state on pg

BEGIN;

    DO $$
    DECLARE
        object_name text;
        generated_count integer;
    BEGIN
        FOREACH object_name IN ARRAY ARRAY[
            'api_refresh_state',
            'api_leaderboard_player',
            'api_leaderboard_guild',
            'api_leaderboard_reactor',
            'api_leaderboard_substation',
            'api_leaderboard_provider',
            'api_inventory',
            'api_guild_bank'
        ]
        LOOP
            IF to_regclass('structs.' || object_name) IS NULL THEN
                RAISE EXCEPTION 'expected structs.% to exist', object_name;
            END IF;
        END LOOP;

        FOREACH object_name IN ARRAY ARRAY[
            'api_leaderboard_player_alpha_balance_idx',
            'api_leaderboard_player_alpha_value_idx',
            'api_leaderboard_guild_collateral_idx',
            'api_leaderboard_guild_ratio_idx',
            'api_leaderboard_guild_player_count_idx',
            'api_leaderboard_reactor_fuel_idx',
            'api_leaderboard_reactor_power_idx',
            'api_leaderboard_substation_load_idx',
            'api_leaderboard_substation_member_capacity_idx',
            'api_leaderboard_substation_connection_capacity_idx',
            'api_leaderboard_substation_player_count_idx',
            'api_leaderboard_provider_rate_idx',
            'api_leaderboard_provider_agreement_count_idx'
        ]
        LOOP
            IF to_regclass('structs.' || object_name) IS NULL THEN
                RAISE EXCEPTION 'expected structs.% to exist', object_name;
            END IF;
        END LOOP;

        SELECT count(*) INTO generated_count
          FROM pg_attribute
         WHERE attrelid IN (
                   'structs.api_leaderboard_guild'::regclass,
                   'structs.api_guild_bank'::regclass
               )
           AND attname = 'ratio'
           AND attgenerated = 's';
        IF generated_count <> 2 THEN
            RAISE EXCEPTION 'expected two stored generated ratio columns, found %',
                generated_count;
        END IF;

        IF (
            SELECT format_type(atttypid, atttypmod)
              FROM pg_attribute
             WHERE attrelid = 'structs.api_inventory'::regclass
               AND attname = 'owner_type'
        ) <> 'structs.object_type' THEN
            RAISE EXCEPTION 'structs.api_inventory.owner_type has unexpected type';
        END IF;
    END
    $$;

ROLLBACK;
