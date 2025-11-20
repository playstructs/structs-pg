-- Deploy structs-pg:table-struct-type-20251120-add-energy-precision to pg

BEGIN;

    ALTER TABLE structs.struct_type RENAME COLUMN build_draw TO build_draw_p;
    ALTER TABLE structs.struct_type RENAME COLUMN passive_draw TO passive_draw_p;

    ALTER TABLE structs.struct_type ADD COLUMN build_draw NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(build_draw_p, 'ualpha')) STORED;
    ALTER TABLE structs.struct_type ADD COLUMN passive_draw NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(passive_draw_p, 'ualpha')) STORED;

COMMIT;
