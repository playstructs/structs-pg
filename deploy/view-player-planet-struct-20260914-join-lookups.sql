-- Deploy structs-pg:view-player-planet-struct-20260914-join-lookups to pg
--
-- Same columns and expressions as the current player/planet/struct views.
-- Replace per-column correlated subqueries with joins so listing many rows
-- does not re-probe grid/attributes for the same object.

BEGIN;

    CREATE OR REPLACE VIEW view.player AS
        SELECT
            player.id AS player_id,
            player.username,
            player.pfp,
            player.pfp_client_render_attributes,
            player.guild_id,
            player.substation_id,
            player.planet_id,
            player.fleet_id,
            COALESCE(g.ore, 0) AS ore,

            COALESCE(g.load, 0) AS load_p,
            floor(COALESCE(g.load, 0) / 1000) AS load,

            COALESCE(g.structs_load, 0) AS structs_load_p,
            floor(COALESCE(g.structs_load, 0) / 1000) AS structs_load,

            COALESCE(g.capacity, 0) AS capacity_p,
            floor(COALESCE(g.capacity, 0) / 1000) AS capacity,

            COALESCE(gcc.connection_capacity, 0) AS connection_capacity_p,
            floor(COALESCE(gcc.connection_capacity, 0) / 1000) AS connection_capacity,

            COALESCE(g.load, 0) + COALESCE(g.structs_load, 0) AS total_load_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE(g.load, 0) + COALESCE(g.structs_load, 0),
                'milliwatt'
            ) AS total_load,

            COALESCE(g.capacity, 0) + COALESCE(gcc.connection_capacity, 0) AS total_capacity_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE(g.capacity, 0) + COALESCE(gcc.connection_capacity, 0),
                'milliwatt'
            ) AS total_capacity,

            player.primary_address,
            player.created_at,
            player.updated_at
        FROM structs.player
        LEFT JOIN LATERAL (
            SELECT
                MAX(grid.val) FILTER (WHERE grid.attribute_type = 'ore') AS ore,
                MAX(grid.val) FILTER (WHERE grid.attribute_type = 'load') AS load,
                MAX(grid.val) FILTER (WHERE grid.attribute_type = 'structsLoad') AS structs_load,
                MAX(grid.val) FILTER (WHERE grid.attribute_type = 'capacity') AS capacity
            FROM structs.grid
            WHERE grid.object_id = player.id
              AND grid.attribute_type IN ('ore', 'load', 'structsLoad', 'capacity')
        ) g ON true
        LEFT JOIN LATERAL (
            SELECT grid.val AS connection_capacity
            FROM structs.grid
            WHERE grid.object_id = player.substation_id
              AND grid.attribute_type = 'connectionCapacity'
            LIMIT 1
        ) gcc ON true;

    CREATE OR REPLACE VIEW view.planet AS
        SELECT
            planet.id AS planet_id,
            planet.name,
            planet.max_ore,
            COALESCE(g_buried.val, 0) AS buried_ore,
            COALESCE(g_avail.val, 0) AS available_ore,

            COALESCE(pa0.val, 0) AS planetary_shield,
            COALESCE(pa1.val, 0) AS repair_network_quantity,
            COALESCE(pa2.val, 0) AS defensive_cannon_quantity,
            COALESCE(pa3.val, 0) AS coordinated_global_shield_network_quantity,

            COALESCE(pa4.val, 0) AS low_orbit_ballistics_interceptor_network_quantity,
            COALESCE(pa5.val, 0) AS advanced_low_orbit_ballistics_interceptor_network_quantity,

            COALESCE(pa6.val, 0) AS lobi_network_success_rate_numerator,
            COALESCE(pa7.val, 0) AS lobi_network_success_rate_denominator,

            COALESCE(pa8.val, 0) AS orbital_jamming_station_quantity,
            COALESCE(pa9.val, 0) AS advanced_orbital_jamming_station_quantity,

            COALESCE(pa10.val, 0) AS block_start_raid,
            COALESCE(pa11.val, 0) AS block_raider_arrived,
            COALESCE(pa12.val, 0) AS block_start_ore_mine,
            COALESCE(pa13.val, 0) AS block_start_ore_refine,
            COALESCE(pa14.val, 0) AS ore_mining_active_quantity,
            COALESCE(pa15.val, 0) AS ore_refining_active_quantity,

            planet.creator,
            planet.owner,
            planet.status,
            planet.created_at,
            planet.updated_at
        FROM structs.planet
            LEFT JOIN structs.grid g_buried ON g_buried.id = '0-' || planet.id
            LEFT JOIN structs.grid g_avail ON g_avail.id = '0-' || planet.owner
            LEFT JOIN structs.planet_attribute pa0 ON pa0.id = '0-' || planet.id
            LEFT JOIN structs.planet_attribute pa1 ON pa1.id = '1-' || planet.id
            LEFT JOIN structs.planet_attribute pa2 ON pa2.id = '2-' || planet.id
            LEFT JOIN structs.planet_attribute pa3 ON pa3.id = '3-' || planet.id
            LEFT JOIN structs.planet_attribute pa4 ON pa4.id = '4-' || planet.id
            LEFT JOIN structs.planet_attribute pa5 ON pa5.id = '5-' || planet.id
            LEFT JOIN structs.planet_attribute pa6 ON pa6.id = '6-' || planet.id
            LEFT JOIN structs.planet_attribute pa7 ON pa7.id = '7-' || planet.id
            LEFT JOIN structs.planet_attribute pa8 ON pa8.id = '8-' || planet.id
            LEFT JOIN structs.planet_attribute pa9 ON pa9.id = '9-' || planet.id
            LEFT JOIN structs.planet_attribute pa10 ON pa10.id = '10-' || planet.id
            LEFT JOIN structs.planet_attribute pa11 ON pa11.id = '11-' || planet.id
            LEFT JOIN structs.planet_attribute pa12 ON pa12.id = '12-' || planet.id
            LEFT JOIN structs.planet_attribute pa13 ON pa13.id = '13-' || planet.id
            LEFT JOIN structs.planet_attribute pa14 ON pa14.id = '14-' || planet.id
            LEFT JOIN structs.planet_attribute pa15 ON pa15.id = '15-' || planet.id;

    CREATE OR REPLACE VIEW view.struct AS
        SELECT
            struct.id AS struct_id,
            struct.index,

            struct.location_type,
            struct.location_id,
            struct.operating_ambit,
            struct.slot,

            COALESCE(sa_health.val, 0) AS health,
            COALESCE(sa_status.val, 0) AS status,
            (COALESCE(sa_status.val, 0) & 2) > 0 AS is_built,
            (COALESCE(sa_status.val, 0) & 4) > 0 AS is_online,
            struct.is_destroyed,

            COALESCE(sa_build.val, 0) AS block_start_build,
            COALESCE(pa_mine.val, 0) AS block_start_ore_mine,
            COALESCE(pa_refine.val, 0) AS block_start_ore_refine,

            COALESCE(sa_prot.val, 0) AS protected_struct_index,
            NULLIF(
                '5-' || COALESCE(sa_prot.val, 0)::text,
                '5-0'
            ) AS protected_struct_id,

            COALESCE(g_fuel.val, 0) AS generator_fuel_p,
            floor(COALESCE(g_fuel.val, 0) / 1000000) AS generator_fuel,

            COALESCE(g_load.val, 0) AS generator_load_p,
            floor(COALESCE(g_load.val, 0) / 1000) AS generator_load,

            COALESCE(g_cap.val, 0) AS generator_capacity_p,
            floor(COALESCE(g_cap.val, 0) / 1000) AS generator_capacity,

            struct_type.id AS struct_type_id,
            struct_type.type,
            struct_type.category,
            struct_type.class,
            struct_type.class_abbreviation,
            struct_type.is_command,
            struct_type.default_cosmetic_model_number,
            struct_type.default_cosmetic_name,
            struct_type.build_limit,
            struct_type.build_difficulty,
            struct_type.build_draw,
            struct_type.build_draw_p,
            struct_type.max_health,
            struct_type.passive_draw,
            struct_type.passive_draw_p,
            struct_type.possible_ambit_array,
            struct_type.possible_ambit,
            struct_type.movable,
            struct_type.slot_bound,
            struct_type.primary_weapon,
            struct_type.primary_weapon_control,
            struct_type.primary_weapon_charge,
            struct_type.primary_weapon_ambits,
            struct_type.primary_weapon_ambits_array,
            struct_type.primary_weapon_targets,
            struct_type.primary_weapon_shots,
            struct_type.primary_weapon_damage,
            struct_type.primary_weapon_blockable,
            struct_type.primary_weapon_counterable,
            struct_type.primary_weapon_armour_piercing,
            struct_type.primary_weapon_recoil_damage,
            struct_type.primary_weapon_shot_success_rate_numerator,
            struct_type.primary_weapon_shot_success_rate_denominator,
            struct_type.secondary_weapon,
            struct_type.secondary_weapon_control,
            struct_type.secondary_weapon_charge,
            struct_type.secondary_weapon_ambits,
            struct_type.secondary_weapon_ambits_array,
            struct_type.secondary_weapon_targets,
            struct_type.secondary_weapon_shots,
            struct_type.secondary_weapon_damage,
            struct_type.secondary_weapon_blockable,
            struct_type.secondary_weapon_counterable,
            struct_type.secondary_weapon_armour_piercing,
            struct_type.secondary_weapon_recoil_damage,
            struct_type.secondary_weapon_shot_success_rate_numerator,
            struct_type.secondary_weapon_shot_success_rate_denominator,
            struct_type.passive_weaponry,
            struct_type.unit_defenses,
            struct_type.ore_reserve_defenses,
            struct_type.planetary_defenses,
            struct_type.planetary_mining,
            struct_type.planetary_refinery,
            struct_type.power_generation,
            struct_type.activate_charge,
            struct_type.build_charge,
            struct_type.defend_change_charge,
            struct_type.move_charge,
            struct_type.stealth_activate_charge,
            struct_type.attack_reduction,
            struct_type.attack_counterable,
            struct_type.stealth_systems,
            struct_type.counter_attack,
            struct_type.counter_attack_same_ambit,
            struct_type.post_destruction_damage,
            struct_type.generating_rate,
            struct_type.generating_rate_p,
            struct_type.planetary_shield_contribution,
            struct_type.ore_mining_difficulty,
            struct_type.ore_refining_difficulty,
            struct_type.unguided_defensive_success_rate_numerator,
            struct_type.unguided_defensive_success_rate_denominator,
            struct_type.guided_defensive_success_rate_numerator,
            struct_type.guided_defensive_success_rate_denominator,
            struct_type.trigger_raid_defeat_by_destruction,
            struct_type.updated_at,

            struct.creator,
            struct.owner,
            struct.created_at AS struct_created_at,
            struct.updated_at AS struct_updated_at
        FROM structs.struct
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.struct_attribute sa_health ON sa_health.id = '0-' || struct.id
            LEFT JOIN structs.struct_attribute sa_status ON sa_status.id = '1-' || struct.id
            LEFT JOIN structs.struct_attribute sa_build ON sa_build.id = '2-' || struct.id
            LEFT JOIN structs.struct_attribute sa_prot ON sa_prot.id = '5-' || struct.id
            LEFT JOIN structs.planet_attribute pa_mine ON pa_mine.id = '12-' || struct.location_id
            LEFT JOIN structs.planet_attribute pa_refine ON pa_refine.id = '13-' || struct.location_id
            LEFT JOIN structs.grid g_fuel ON g_fuel.id = '1-' || struct.id
            LEFT JOIN structs.grid g_load ON g_load.id = '3-' || struct.id
            LEFT JOIN structs.grid g_cap ON g_cap.id = '2-' || struct.id;

COMMIT;
