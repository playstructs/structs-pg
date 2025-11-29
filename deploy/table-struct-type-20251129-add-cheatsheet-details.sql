-- Deploy structs-pg:table-struct-type-20251129-add-cheatsheet-details to pg

BEGIN;

    UPDATE structs.struct_type SET
            type='Submersible',
            class='Submersible',
            class_abbreviation='Submersible'
    WHERE default_cosmetic_model_number='LV-2';

    UPDATE structs.struct_type SET
           type='Battleship',
           class='Battleship'
    WHERE default_cosmetic_model_number='CT-C';

    ALTER TABLE structs.struct_type ADD COLUMN primary_weapon_ambits_array jsonb GENERATED ALWAYS AS (structs.flag_to_ambits(primary_weapon_ambits)::jsonb) STORED;
    ALTER TABLE structs.struct_type ADD COLUMN secondary_weapon_ambits_array jsonb GENERATED ALWAYS AS (structs.flag_to_ambits(secondary_weapon_ambits)::jsonb) STORED;

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



    ALTER TABLE structs.struct_type ADD COLUMN unit_description TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN primary_weapon_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN primary_weapon_description TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN primary_weapon_class TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN secondary_weapon_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN secondary_weapon_class TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN ability_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN ability_description TEXT;

    UPDATE structs.struct_type SET
        unit_description=struct_type_cs.unit_description,
        primary_weapon_label=struct_type_cs.primary_weapon_label,
        primary_weapon_description=struct_type_cs.primary_weapon_description,
        primary_weapon_class=struct_type_cs.primary_weapon_class,
        secondary_weapon_label=struct_type_cs.secondary_weapon_label,
        secondary_weapon_class=struct_type_cs.secondary_weapon_class,
        ability_label=struct_type_cs.ability_label,
        ability_description=struct_type_cs.ability_description
    FROM structs.struct_type_cs
    WHERE struct_type_cs.class=struct_type.class;

COMMIT;
