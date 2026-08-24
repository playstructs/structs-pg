-- Deploy structs-pg:view-planet-20260824-ore-clocks to pg
--
-- structsd v0.21.0 added planet attributes 11-15 (raid-pause clock, shared
-- ore clocks, and active mine/refine quantities).

BEGIN;

    DROP VIEW IF EXISTS view.planet CASCADE;

    CREATE VIEW view.planet AS
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

COMMIT;
