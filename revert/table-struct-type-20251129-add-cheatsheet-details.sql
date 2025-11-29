-- Revert structs-pg:table-struct-type-20251129-add-cheatsheet-details from pg

BEGIN;

    ALTER TABLE structs.struct_type DROP COLUMN ability_description ;
    ALTER TABLE structs.struct_type DROP COLUMN ability_label ;
    ALTER TABLE structs.struct_type DROP COLUMN secondary_weapon_class ;
    ALTER TABLE structs.struct_type DROP COLUMN secondary_weapon_label ;
    ALTER TABLE structs.struct_type DROP COLUMN primary_weapon_class ;

    ALTER TABLE structs.struct_type DROP COLUMN primary_weapon_description ;

    ALTER TABLE structs.struct_type DROP COLUMN primary_weapon_label ;
    ALTER TABLE structs.struct_type DROP COLUMN unit_description ;

    ALTER TABLE structs.struct_type DROP COLUMN secondary_weapon_ambits_array;
    ALTER TABLE structs.struct_type DROP COLUMN primary_weapon_ambits_array;

    DROP TABLE structs.struct_type_cs;

COMMIT;
