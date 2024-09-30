-- Deploy structs-pg:view-planet to pg

BEGIN;

CREATE OR REPLACE VIEW view.planet AS
        SELECT
            id as planet_id,
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

            creator,
            owner,
            status,
            created_at,
            updated_at
        FROM structs.planet;

COMMIT;
