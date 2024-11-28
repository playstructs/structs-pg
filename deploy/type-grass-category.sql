-- Deploy structs-pg:type-grass-category to pg

BEGIN;

    CREATE TYPE structs.grass_category AS ENUM (
        -- Consensus
        'block',

        -- Guild
        'guild_consensus',
        'guild_meta',
        'guild_membership',

        -- Planet Activity
        'raid_status',
        'fleet_arrive',
        'fleet_advance',
        'fleet_depart',
        'struct_attack',
        'struct_defense_remove',
        'struct_defense_add',
        'struct_status',
        'struct_move',
        'struct_block_build_start',
        'struct_block_ore_mine_start',
        'struct_block_ore_refine_start',

        -- Player
        'player_consensus',
        'player_meta'
    );


COMMIT;
