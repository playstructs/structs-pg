-- Revert structs-pg:table-struct-type-20260810-cheatsheet-command-ablative-copy from pg
--
-- Restores prior Command Ship passive-weaponry copy and Ablative Armour
-- unit-defense description, then re-burns struct_type_cs into struct_type.

BEGIN;

    UPDATE structs.struct_type_cs
       SET passive_weaponry_label       = 'Strong Counter-Attack',
           passive_weaponry_description = ''
     WHERE class = 'Command Ship' AND language = 'EN';

    UPDATE structs.struct_type_cs
       SET unit_defenses_description = 'Reduces all incoming DMG to 1.'
     WHERE unit_defenses_label = 'Ablative Armour' AND language = 'EN';

    UPDATE structs.struct_type SET
        unit_description=struct_type_cs.unit_description,
        primary_weapon_label=struct_type_cs.primary_weapon_label,
        primary_weapon_description=struct_type_cs.primary_weapon_description,
        primary_weapon_class=struct_type_cs.primary_weapon_class,
        secondary_weapon_label=struct_type_cs.secondary_weapon_label,
        secondary_weapon_class=struct_type_cs.secondary_weapon_class,
        drive_label=struct_type_cs.drive_label,
        drive_description=struct_type_cs.drive_description,
        passive_weaponry_label=struct_type_cs.passive_weaponry_label,
        passive_weaponry_description=struct_type_cs.passive_weaponry_description,
        unit_defenses_label=struct_type_cs.unit_defenses_label,
        unit_defenses_description=struct_type_cs.unit_defenses_description,
        ore_reserve_defenses_label=struct_type_cs.ore_reserve_defenses_label,
        ore_reserve_defenses_description=struct_type_cs.ore_reserve_defenses_description,
        planetary_defenses_label=struct_type_cs.planetary_defenses_label,
        planetary_defenses_description=struct_type_cs.planetary_defenses_description,
        planetary_mining_label=struct_type_cs.planetary_mining_label,
        planetary_mining_description=struct_type_cs.planetary_mining_description,
        planetary_refineries_label=struct_type_cs.planetary_refineries_label,
        planetary_refineries_description=struct_type_cs.planetary_refineries_description,
        power_generation_label=struct_type_cs.power_generation_label,
        power_generation_description=struct_type_cs.power_generation_description
    FROM structs.struct_type_cs
    WHERE struct_type_cs.class=struct_type.class;

COMMIT;
