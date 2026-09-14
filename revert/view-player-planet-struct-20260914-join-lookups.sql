-- Revert structs-pg:view-player-planet-struct-20260914-join-lookups from pg
--
-- Restores correlated-subquery definitions from
-- view-player-20260901-fix-total-load-capacity,
-- view-planet-20260824-ore-clocks, and
-- view-struct-20260904-add-state-columns.

BEGIN;

    CREATE OR REPLACE VIEW view.player AS
        SELECT
            player.id as player_id,
            player.username,
            player.pfp,
            player.pfp_client_render_attributes,
            player.guild_id,
            player.substation_id,
            player.planet_id,
            player.fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='ore'),0) as ore,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) as load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0)/1000) as load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as structs_load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as structs_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) as capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0)/1000) as capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0) as connection_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000) as connection_capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as total_load_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0),
                'milliwatt'
            ) as total_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)  as total_capacity_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0),
                'milliwatt'
            ) as total_capacity,

            player.primary_address,
            player.created_at,
            player.updated_at
        FROM structs.player;

    CREATE OR REPLACE VIEW view.planet AS
        SELECT
            id as planet_id,
            name,
            max_ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.id),0) as buried_ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.owner),0) as available_ore,

            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='0-' || planet.id),0) as  planetary_shield,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='1-' || planet.id),0) as  repair_network_quantity,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='2-' || planet.id),0) as  defensive_cannon_quantity,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='3-' || planet.id),0) as  coordinated_global_shield_network_quantity,

            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='4-' || planet.id),0) as  low_orbit_ballistics_interceptor_network_quantity,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='5-' || planet.id),0) as  advanced_low_orbit_ballistics_interceptor_network_quantity,

            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='6-' || planet.id),0) as  lobi_network_success_rate_numerator,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='7-' || planet.id),0) as  lobi_network_success_rate_denominator,

            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='8-' || planet.id),0) as  orbital_jamming_station_quantity,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='9-' || planet.id),0) as  advanced_orbital_jamming_station_quantity,

            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='10-' || planet.id),0) as  block_start_raid,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='11-' || planet.id),0) as  block_raider_arrived,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='12-' || planet.id),0) as  block_start_ore_mine,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='13-' || planet.id),0) as  block_start_ore_refine,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='14-' || planet.id),0) as  ore_mining_active_quantity,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='15-' || planet.id),0) as  ore_refining_active_quantity,

            creator,
            owner,
            status,
            created_at,
            updated_at
        FROM structs.planet;

    CREATE OR REPLACE VIEW view.struct AS
        SELECT
            struct.id as struct_id,
            index,

            location_type,
            location_id,
            operating_ambit,
            slot,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='0-' || struct.id),0) as  health,
            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='1-' || struct.id),0) as  status,
            (COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='1-' || struct.id),0) & 2) > 0 as is_built,
            (COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='1-' || struct.id),0) & 4) > 0 as is_online,
            struct.is_destroyed,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='2-' || struct.id),0) as  block_start_build,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='12-' || struct.location_id),0) as  block_start_ore_mine,
            COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='13-' || struct.location_id),0) as  block_start_ore_refine,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='5-' || struct.id),0) as  protected_struct_index,
            NULLIF(
                '5-' || COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='5-' || struct.id),0)::text,
                '5-0'
            ) as protected_struct_id,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || struct.id),0) as generator_fuel_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || struct.id),0)/1000000) as generator_fuel,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || struct.id),0) as generator_load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || struct.id),0)/1000) as generator_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || struct.id),0) as generator_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || struct.id),0)/1000) as generator_capacity,

            struct_type.id as struct_type_id,
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
            struct.created_at as struct_created_at,
            struct.updated_at as struct_updated_at
        FROM structs.struct, structs.struct_type
        WHERE struct_type.id = struct.type;

COMMIT;
