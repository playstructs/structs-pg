-- Revert structs-pg:planet-sector-20261110 from pg
-- Stop/roll back the sector-aware writer first. Export sector data if needed.
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE TEMP TABLE planet_sector_view_acl ON COMMIT DROP AS
SELECT pg_get_userbyid(c.relowner) AS owner, a.grantee,
       a.privilege_type, a.is_grantable
FROM pg_class c LEFT JOIN LATERAL aclexplode(c.relacl) a ON true
WHERE c.oid = 'view.planet'::regclass;
-- Deliberately no CASCADE: downstream dependencies must be rolled back first.
DROP VIEW view.planet;
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
DO $$
DECLARE entry record; old_owner text;
BEGIN
    SELECT owner INTO old_owner FROM planet_sector_view_acl LIMIT 1;
    EXECUTE format('ALTER VIEW view.planet OWNER TO %I', old_owner);
    FOR entry IN SELECT * FROM planet_sector_view_acl WHERE grantee IS NOT NULL LOOP
        EXECUTE format('GRANT %s ON view.planet TO %s%s', entry.privilege_type,
            CASE WHEN entry.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(entry.grantee)) END,
            CASE WHEN entry.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
END $$;
ALTER TABLE structs.planet DROP COLUMN sector;
COMMIT;
