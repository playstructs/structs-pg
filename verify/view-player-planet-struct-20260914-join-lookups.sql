-- Verify structs-pg:view-player-planet-struct-20260914-join-lookups on pg

BEGIN;

    SELECT player_id, ore, load, load_p, structs_load, structs_load_p,
           capacity, capacity_p, connection_capacity, connection_capacity_p,
           total_load, total_load_p, total_capacity, total_capacity_p,
           pfp_client_render_attributes
    FROM view.player
    WHERE FALSE;

    SELECT planet_id, name, buried_ore, available_ore,
           block_start_raid, block_raider_arrived,
           block_start_ore_mine, block_start_ore_refine,
           ore_mining_active_quantity, ore_refining_active_quantity
    FROM view.planet
    WHERE FALSE;

    SELECT struct_id, health, status, is_built, is_online, is_destroyed,
           protected_struct_index, protected_struct_id,
           block_start_build, block_start_ore_mine, block_start_ore_refine
    FROM view.struct
    WHERE FALSE;

    DO $$
    DECLARE
        player_def text;
        planet_def text;
        struct_def text;
    BEGIN
        SELECT pg_get_viewdef('view.player'::regclass, true) INTO player_def;
        SELECT pg_get_viewdef('view.planet'::regclass, true) INTO planet_def;
        SELECT pg_get_viewdef('view.struct'::regclass, true) INTO struct_def;

        IF player_def NOT ILIKE '%unit_legacy_format(%' THEN
            RAISE EXCEPTION 'view.player total_load/total_capacity should use UNIT_LEGACY_FORMAT';
        END IF;
        IF position('LATERAL' in player_def) = 0 THEN
            RAISE EXCEPTION 'view.player should join grid via LATERAL';
        END IF;

        IF position('''12-''' in planet_def) = 0 OR position('''13-''' in planet_def) = 0 THEN
            RAISE EXCEPTION 'view.planet does not look up planet ore clocks (12-/13-)';
        END IF;
        IF position('''11-''' in planet_def) = 0
            OR position('''14-''' in planet_def) = 0
            OR position('''15-''' in planet_def) = 0 THEN
            RAISE EXCEPTION 'view.planet does not look up planet attrs 11/14/15';
        END IF;

        IF position('is_built' in struct_def) = 0
            OR position('is_online' in struct_def) = 0
            OR position('is_destroyed' in struct_def) = 0
            OR position('protected_struct_id' in struct_def) = 0 THEN
            RAISE EXCEPTION 'view.struct missing state columns';
        END IF;
        IF position('''12-''' in struct_def) = 0 OR position('''13-''' in struct_def) = 0 THEN
            RAISE EXCEPTION 'view.struct does not look up planet ore clocks (12-/13-)';
        END IF;
    END
    $$;

ROLLBACK;
