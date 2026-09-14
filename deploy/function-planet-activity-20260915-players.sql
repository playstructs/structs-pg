-- Deploy structs-pg:function-planet-activity-20260915-players to pg
--
-- The specification of "which players does this planet_activity row belong
-- to". Today the webapp answers that at read time with six OR'd predicates
-- over detail JSON and current ownership, which forces a scan of every
-- chunk per page. This function answers it once per row at write time (see
-- table-planet-activity-player-20260915-attribution) and is what the
-- reconciler compares against.
--
-- Branches mirror TableReadManager::planetActivityPlayerBranches() in
-- structs-webapp, with roles added and two deliberate improvements:
--
--   struct_attack           detail.attackerPlayerId                -> attacker
--                           detail.eventAttackShotDetail[].targetPlayerId -> target
--   struct_status, struct_health, struct_move,
--   struct_block_build_start, struct_block_ore_mine_start,
--   struct_block_ore_refine_start
--                           owner(detail.struct_id)                -> owner
--                           when detail has planet_id and no struct_id
--                           (planet-level mine/refine clocks, ~61k rows the
--                           webapp currently drops): owner(planet) -> planet_owner
--   struct_defense_add, struct_defense_remove
--                           owner(detail.defender_struct_id)       -> defender
--                           owner(detail.protected_struct_id)      -> protected (new)
--   raid_status, fleet_arrive, fleet_depart
--                           owner(detail.fleet_id)                 -> fleet_owner
--                           owner(planet_id)                       -> planet_owner
--   shield_change, block_raid_start
--                           owner(planet_id)                       -> planet_owner
--
-- Ownership comes from structs.player_object, which sync-state maintains for
-- every struct, fleet and planet and which matched struct.owner, fleet.owner
-- and planet.owner on every row in production when this was written. The
-- base tables are the fallback.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.object_owner(p_object_id CHARACTER VARYING)
    RETURNS CHARACTER VARYING
    LANGUAGE sql
    STABLE
    PARALLEL SAFE
    AS
    $BODY$
        SELECT COALESCE(
            (SELECT NULLIF(po.player_id, '') FROM structs.player_object po WHERE po.object_id = p_object_id),
            CASE split_part(p_object_id, '-', 1)
                WHEN '5' THEN (SELECT NULLIF(s.owner, '') FROM structs.struct s WHERE s.id = p_object_id)
                WHEN '9' THEN (SELECT NULLIF(f.owner, '') FROM structs.fleet  f WHERE f.id = p_object_id)
                WHEN '2' THEN (SELECT NULLIF(p.owner, '') FROM structs.planet p WHERE p.id = p_object_id)
            END
        )
        WHERE p_object_id IS NOT NULL AND p_object_id <> '';
    $BODY$;

    COMMENT ON FUNCTION structs.object_owner(CHARACTER VARYING) IS
        'Current owning player of a struct (5-), fleet (9-) or planet (2-) id, from player_object with the base table as fallback. NULL when unknown.';

    CREATE OR REPLACE FUNCTION structs.planet_activity_players(
        p_category  structs.grass_category,
        p_planet_id CHARACTER VARYING,
        p_detail    JSONB
    )
    RETURNS TABLE (player_id CHARACTER VARYING, role TEXT)
    LANGUAGE sql
    STABLE
    PARALLEL SAFE
    AS
    $BODY$
        WITH raw(player_id, role) AS (
            -- attacks: the attacker and every shot's target
            SELECT NULLIF(p_detail->>'attackerPlayerId', '')::CHARACTER VARYING, 'attacker'
             WHERE p_category = 'struct_attack'
            UNION ALL
            SELECT NULLIF(shot->>'targetPlayerId', '')::CHARACTER VARYING, 'target'
              FROM jsonb_array_elements(
                       CASE WHEN p_category = 'struct_attack'
                             AND jsonb_typeof(p_detail->'eventAttackShotDetail') = 'array'
                            THEN p_detail->'eventAttackShotDetail'
                            ELSE '[]'::jsonb END
                   ) shot

            -- struct events: the struct's owner
            UNION ALL
            SELECT structs.object_owner(p_detail->>'struct_id'), 'owner'
             WHERE p_category IN ('struct_status', 'struct_health', 'struct_move',
                                  'struct_block_build_start',
                                  'struct_block_ore_mine_start',
                                  'struct_block_ore_refine_start')
               AND p_detail ? 'struct_id'
            -- planet-level mine/refine clocks carry planet_id, not struct_id
            UNION ALL
            SELECT structs.object_owner(COALESCE(NULLIF(p_detail->>'planet_id', ''), p_planet_id)), 'planet_owner'
             WHERE p_category IN ('struct_block_ore_mine_start', 'struct_block_ore_refine_start')
               AND NOT (p_detail ? 'struct_id')

            -- defenders
            UNION ALL
            SELECT structs.object_owner(p_detail->>'defender_struct_id'), 'defender'
             WHERE p_category IN ('struct_defense_add', 'struct_defense_remove')
            UNION ALL
            SELECT structs.object_owner(p_detail->>'protected_struct_id'), 'protected'
             WHERE p_category IN ('struct_defense_add', 'struct_defense_remove')

            -- fleets and raids: fleet owner and planet owner
            UNION ALL
            SELECT structs.object_owner(p_detail->>'fleet_id'), 'fleet_owner'
             WHERE p_category IN ('raid_status', 'fleet_arrive', 'fleet_depart')
            UNION ALL
            SELECT structs.object_owner(p_planet_id), 'planet_owner'
             WHERE p_category IN ('raid_status', 'fleet_arrive', 'fleet_depart',
                                  'shield_change', 'block_raid_start')
        )
        SELECT DISTINCT raw.player_id, raw.role
          FROM raw
         WHERE raw.player_id IS NOT NULL;
    $BODY$;

    COMMENT ON FUNCTION structs.planet_activity_players(structs.grass_category, CHARACTER VARYING, JSONB) IS
        'Specification of player attribution for a planet_activity row: (player_id, role) pairs with role in attacker, target, owner, planet_owner, defender, protected, fleet_owner. Evaluated at insert time by the planet_activity_attribute trigger.';

COMMIT;
