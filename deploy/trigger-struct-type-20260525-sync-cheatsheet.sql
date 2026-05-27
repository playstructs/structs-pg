-- Deploy structs-pg:trigger-struct-type-20260525-sync-cheatsheet to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.STRUCT_TYPE_SYNC_CS()
        RETURNS trigger AS
    $BODY$
    DECLARE
        _cs structs.struct_type_cs%ROWTYPE;
    BEGIN
        SELECT *
        INTO _cs
        FROM structs.struct_type_cs
        WHERE class = NEW.class
          AND language = 'EN';

        IF FOUND THEN
            NEW.unit_description := _cs.unit_description;
            NEW.primary_weapon_label := _cs.primary_weapon_label;
            NEW.primary_weapon_description := _cs.primary_weapon_description;
            NEW.primary_weapon_class := _cs.primary_weapon_class;
            NEW.secondary_weapon_label := _cs.secondary_weapon_label;
            NEW.secondary_weapon_class := _cs.secondary_weapon_class;
            NEW.drive_label := _cs.drive_label;
            NEW.drive_description := _cs.drive_description;
            NEW.passive_weaponry_label := _cs.passive_weaponry_label;
            NEW.passive_weaponry_description := _cs.passive_weaponry_description;
            NEW.unit_defenses_label := _cs.unit_defenses_label;
            NEW.unit_defenses_description := _cs.unit_defenses_description;
            NEW.ore_reserve_defenses_label := _cs.ore_reserve_defenses_label;
            NEW.ore_reserve_defenses_description := _cs.ore_reserve_defenses_description;
            NEW.planetary_defenses_label := _cs.planetary_defenses_label;
            NEW.planetary_defenses_description := _cs.planetary_defenses_description;
            NEW.planetary_mining_label := _cs.planetary_mining_label;
            NEW.planetary_mining_description := _cs.planetary_mining_description;
            NEW.planetary_refineries_label := _cs.planetary_refineries_label;
            NEW.planetary_refineries_description := _cs.planetary_refineries_description;
            NEW.power_generation_label := _cs.power_generation_label;
            NEW.power_generation_description := _cs.power_generation_description;
        END IF;

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER STRUCT_TYPE_SYNC_CS
        BEFORE INSERT OR UPDATE ON structs.struct_type
        FOR EACH ROW EXECUTE PROCEDURE structs.STRUCT_TYPE_SYNC_CS();

    UPDATE structs.struct_type SET
        unit_description = struct_type_cs.unit_description,
        primary_weapon_label = struct_type_cs.primary_weapon_label,
        primary_weapon_description = struct_type_cs.primary_weapon_description,
        primary_weapon_class = struct_type_cs.primary_weapon_class,
        secondary_weapon_label = struct_type_cs.secondary_weapon_label,
        secondary_weapon_class = struct_type_cs.secondary_weapon_class,
        drive_label = struct_type_cs.drive_label,
        drive_description = struct_type_cs.drive_description,
        passive_weaponry_label = struct_type_cs.passive_weaponry_label,
        passive_weaponry_description = struct_type_cs.passive_weaponry_description,
        unit_defenses_label = struct_type_cs.unit_defenses_label,
        unit_defenses_description = struct_type_cs.unit_defenses_description,
        ore_reserve_defenses_label = struct_type_cs.ore_reserve_defenses_label,
        ore_reserve_defenses_description = struct_type_cs.ore_reserve_defenses_description,
        planetary_defenses_label = struct_type_cs.planetary_defenses_label,
        planetary_defenses_description = struct_type_cs.planetary_defenses_description,
        planetary_mining_label = struct_type_cs.planetary_mining_label,
        planetary_mining_description = struct_type_cs.planetary_mining_description,
        planetary_refineries_label = struct_type_cs.planetary_refineries_label,
        planetary_refineries_description = struct_type_cs.planetary_refineries_description,
        power_generation_label = struct_type_cs.power_generation_label,
        power_generation_description = struct_type_cs.power_generation_description
    FROM structs.struct_type_cs
    WHERE struct_type_cs.class = struct_type.class
      AND struct_type_cs.language = 'EN';

COMMIT;
