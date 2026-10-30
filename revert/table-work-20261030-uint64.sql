-- Revert structs-pg:table-work-20261030-uint64 from pg
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL search_path=pg_catalog;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.struct_attribute WHERE val>2147483647)
        OR EXISTS (SELECT 1 FROM structs.planet_attribute WHERE val>2147483647)
        OR EXISTS (SELECT 1 FROM structs.struct_type WHERE build_difficulty>2147483647)
        OR EXISTS (SELECT 1 FROM structs.struct_type WHERE ore_mining_difficulty>2147483647)
        OR EXISTS (SELECT 1 FROM structs.struct_type WHERE ore_refining_difficulty>2147483647)
        OR EXISTS (SELECT 1 FROM structs.api_work WHERE block_start>2147483647)
        OR EXISTS (SELECT 1 FROM structs.api_work WHERE difficulty_target>2147483647) THEN
        RAISE EXCEPTION 'work or attribute value exceeds integer; retain uint64 storage or restore a verified checkpoint';
    END IF;
END $$;
-- Preserve view metadata and effective grants while changing output types.
-- Unknown dependent objects cause DROP RESTRICT to fail transactionally.
CREATE TEMP TABLE work_uint64_views ON COMMIT DROP AS
SELECT c.relname,pg_get_userbyid(c.relowner) AS owner,c.reloptions,
       obj_description(c.oid,'pg_class') AS description,
       COALESCE(c.relacl,acldefault('r',c.relowner)) AS acl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='view' AND c.relname IN ('struct_status','planet','struct','work_live','work');
CREATE TEMP TABLE work_uint64_columns ON COMMIT DROP AS
SELECT c.relname,a.attname,a.attacl,col_description(c.oid,a.attnum) AS description
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE n.nspname='view' AND c.relname IN ('struct_status','planet','struct','work_live','work');
CREATE TEMP TABLE work_uint64_triggers ON COMMIT DROP AS
SELECT tgrelid::regclass::text AS relation,tgname,tgenabled,pg_get_triggerdef(oid) AS definition
FROM pg_trigger WHERE tgrelid IN ('structs.struct_attribute'::regclass,'structs.planet_attribute'::regclass)
    AND tgname='api_work_dirty_upd';
DROP TRIGGER api_work_dirty_upd ON structs.struct_attribute;
DROP TRIGGER api_work_dirty_upd ON structs.planet_attribute;
DROP VIEW view.work,view.work_live,view.struct,view.planet,view.struct_status;
ALTER TABLE structs.struct_attribute DROP CONSTRAINT struct_attribute_val_uint64,
    ALTER COLUMN val TYPE INTEGER USING val::integer;
ALTER TABLE structs.planet_attribute DROP CONSTRAINT planet_attribute_val_uint64,
    ALTER COLUMN val TYPE INTEGER USING val::integer;
ALTER TABLE structs.struct_type DROP CONSTRAINT struct_type_build_difficulty_uint64,
    ALTER COLUMN build_difficulty TYPE INTEGER USING build_difficulty::integer;
ALTER TABLE structs.struct_type DROP CONSTRAINT struct_type_ore_mining_difficulty_uint64,
    ALTER COLUMN ore_mining_difficulty TYPE INTEGER USING ore_mining_difficulty::integer;
ALTER TABLE structs.struct_type DROP CONSTRAINT struct_type_ore_refining_difficulty_uint64,
    ALTER COLUMN ore_refining_difficulty TYPE INTEGER USING ore_refining_difficulty::integer;
ALTER TABLE structs.api_work DROP CONSTRAINT api_work_block_start_uint64,
    ALTER COLUMN block_start TYPE INTEGER USING block_start::integer;
ALTER TABLE structs.api_work DROP CONSTRAINT api_work_difficulty_target_uint64,
    ALTER COLUMN difficulty_target TYPE INTEGER USING difficulty_target::integer;

CREATE OR REPLACE VIEW view.struct_status AS
    SELECT
        struct_attribute.object_id as struct_id,
        (struct_attribute.val & 1) > 0 as materialized,
        (struct_attribute.val & 2) > 0 as built,
        (struct_attribute.val & 4) > 0 as online,
        (struct_attribute.val & 8) > 0 as stored,
        (struct_attribute.val & 16) > 0 as hidden,
        (struct_attribute.val & 32) > 0 as destroyed,
        (struct_attribute.val & 64) > 0 as locked,
        struct_attribute.updated_at
    FROM structs.struct_attribute
    WHERE struct_attribute.attribute_type = 'status';

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

CREATE VIEW view.work_live AS
        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'BUILD'::text AS category,
            COALESCE(build_clock.val, 0) AS block_start,
            struct_type.build_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.struct_attribute build_clock
                ON build_clock.object_id = struct.id AND build_clock.attribute_type = 'blockStartBuild'
        WHERE (status.val & 34) = 0 -- not built, not destroyed
            AND struct.is_destroyed IS NOT TRUE

        UNION ALL

        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'MINE'::text AS category,
            COALESCE(mine_clock.val, 0) AS block_start,
            struct_type.ore_mining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.planet_attribute mine_clock
                ON mine_clock.object_id = struct.location_id AND mine_clock.attribute_type = 'blockStartOreMine'
        WHERE (status.val & 4) > 0 -- online
            AND struct.is_destroyed IS NOT TRUE
            AND struct_type.planetary_mining = 'oreMiningRig'
            AND EXISTS (
                SELECT FROM structs.grid planet_ore
                WHERE planet_ore.object_id = struct.location_id
                  AND planet_ore.attribute_type = 'ore'
                  AND planet_ore.val > 0
            )

        UNION ALL

        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'REFINE'::text AS category,
            COALESCE(refine_clock.val, 0) AS block_start,
            struct_type.ore_refining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.planet_attribute refine_clock
                ON refine_clock.object_id = struct.location_id AND refine_clock.attribute_type = 'blockStartOreRefine'
        WHERE (status.val & 4) > 0 -- online
            AND struct.is_destroyed IS NOT TRUE
            AND struct_type.planetary_refinery = 'oreRefinery'
            AND EXISTS (
                SELECT FROM structs.grid player_ore
                WHERE player_ore.object_id = struct.owner
                  AND player_ore.attribute_type = 'ore'
                  AND player_ore.val > 0
            )

        UNION ALL

        SELECT
            planet.location_list_start AS object_id,
            fleet.owner AS player_id,
            planet.id AS target_id,
            'RAID'::text AS category,
            COALESCE(raid_clock.val, 0) AS block_start,
            COALESCE(shield.val, 0) AS difficulty_target,
            'planet'::character varying AS location_type,
            planet.id AS location_id,
            planet.id AS planet_id
        FROM structs.planet
            LEFT JOIN structs.fleet
                ON fleet.id = planet.location_list_start
            LEFT JOIN structs.planet_attribute raid_clock
                ON raid_clock.object_id = planet.id AND raid_clock.attribute_type = 'blockStartRaid'
            LEFT JOIN structs.planet_attribute shield
                ON shield.object_id = planet.id AND shield.attribute_type = 'planetaryShield'
        WHERE planet.location_list_start <> '';

CREATE VIEW view.work AS
SELECT object_id, player_id, target_id, category, block_start,
       difficulty_target, location_type, location_id, planet_id
FROM structs.api_work;

-- Reissue each saved privilege from the view owner, including grant options.
-- Reset any default ACL on the new objects before restoring the saved ACL.
DO $$
DECLARE v RECORD; a RECORD; col RECORD; grantee TEXT;
BEGIN
    FOR v IN SELECT * FROM work_uint64_views ORDER BY relname LOOP
        FOR a IN SELECT DISTINCT x.grantee FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) x
            WHERE c.oid=format('view.%I',v.relname)::regclass LOOP
            grantee := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('REVOKE ALL ON view.%I FROM %s',v.relname,grantee);
        END LOOP;
        EXECUTE format('ALTER VIEW view.%I OWNER TO %I',v.relname,v.owner);
        FOR a IN SELECT * FROM aclexplode(v.acl) LOOP
            grantee := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('SET LOCAL ROLE %I',v.owner);
            EXECUTE format('GRANT %s ON view.%I TO %s%s',a.privilege_type,v.relname,grantee,
                CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
            RESET ROLE;
        END LOOP;
        IF v.reloptions IS NOT NULL THEN
            EXECUTE format('ALTER VIEW view.%I SET (%s)',v.relname,array_to_string(v.reloptions,','));
        END IF;
        EXECUTE format('COMMENT ON VIEW view.%I IS %L',v.relname,v.description);
        FOR col IN SELECT * FROM work_uint64_columns WHERE relname=v.relname LOOP
            EXECUTE format('COMMENT ON COLUMN view.%I.%I IS %L',v.relname,col.attname,col.description);
            FOR a IN SELECT * FROM aclexplode(col.attacl) LOOP
                grantee := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
                EXECUTE format('SET LOCAL ROLE %I',v.owner);
                EXECUTE format('GRANT %s (%I) ON view.%I TO %s%s',a.privilege_type,col.attname,v.relname,grantee,
                    CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
                RESET ROLE;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;
-- Reparse the existing WHEN predicates against the widened columns.
DO $$
DECLARE t RECORD;
BEGIN
    FOR t IN SELECT * FROM work_uint64_triggers LOOP
        EXECUTE t.definition;
        EXECUTE format('ALTER TABLE %s %s TRIGGER %I',t.relation,
            CASE t.tgenabled WHEN 'D' THEN 'DISABLE' WHEN 'A' THEN 'ENABLE ALWAYS'
                WHEN 'R' THEN 'ENABLE REPLICA' ELSE 'ENABLE' END,t.tgname);
    END LOOP;
END $$;
COMMIT;
