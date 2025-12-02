-- Revert structs-pg:table-struct-type-20251202-add-cheatsheet-extended-details from pg

BEGIN;

    DROP TABLE structs.struct_type_cs;

    CREATE TABLE structs.struct_type_cs (
        class CHARACTER VARYING,
        language character varying,
        unit_description TEXT,
        primary_weapon_label TEXT,
        primary_weapon_description TEXT,
        primary_weapon_class TEXT,
        secondary_weapon_label TEXT,
        secondary_weapon_class TEXT,
        ability_label TEXT,
        ability_description TEXT,
        PRIMARY KEY(class, language)
    );


    ALTER TABLE structs.struct_type DROP COLUMN drive_label;
    ALTER TABLE structs.struct_type DROP COLUMN drive_description;

    ALTER TABLE structs.struct_type DROP COLUMN passive_weaponry_label;
    ALTER TABLE structs.struct_type DROP COLUMN passive_weaponry_description;

    ALTER TABLE structs.struct_type DROP COLUMN unit_defenses_label;
    ALTER TABLE structs.struct_type DROP COLUMN unit_defenses_description;

    ALTER TABLE structs.struct_type DROP COLUMN ore_reserve_defenses_label;
    ALTER TABLE structs.struct_type DROP COLUMN ore_reserve_defenses_description;

    ALTER TABLE structs.struct_type DROP COLUMN planetary_defenses_label;
    ALTER TABLE structs.struct_type DROP COLUMN planetary_defenses_description;

    ALTER TABLE structs.struct_type DROP COLUMN planetary_mining_label;
    ALTER TABLE structs.struct_type DROP COLUMN planetary_mining_description;

    ALTER TABLE structs.struct_type DROP COLUMN planetary_refineries_label;
    ALTER TABLE structs.struct_type DROP COLUMN planetary_refineries_description;

    ALTER TABLE structs.struct_type DROP COLUMN power_generation_label;
    ALTER TABLE structs.struct_type DROP COLUMN power_generation_description;

    ALTER TABLE structs.struct_type ADD COLUMN ability_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN ability_description TEXT;


COMMIT;
