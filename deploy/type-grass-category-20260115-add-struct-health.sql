-- Deploy structs-pg:type-grass-category-20260115-add-struct-health to pg

BEGIN;

    ALTER TYPE structs.grass_category ADD VALUE 'struct_health' AFTER 'struct_block_ore_refine_start';

COMMIT;
