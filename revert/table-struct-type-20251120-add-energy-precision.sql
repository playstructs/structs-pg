-- Revert structs-pg:table-struct-type-20251120-add-energy-precision from pg

BEGIN;

    ALTER TABLE structs.struct_type DROP COLUMN build_draw;
    ALTER TABLE structs.struct_type DROP COLUMN passive_draw;

    ALTER TABLE structs.struct_type RENAME COLUMN build_draw_p TO build_draw;
    ALTER TABLE structs.struct_type RENAME COLUMN passive_draw_p TO passive_draw;

COMMIT;
