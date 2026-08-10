-- Deploy structs-pg:table-struct-type-20260810-cheatsheet-command-ablative-copy to pg
--
-- Corrects two cheatsheet copy mistakes in struct_type_cs:
--   * Command Ship passive weaponry was labeled "Strong Counter-Attack" with an
--     empty description; it should be "Chimera Counter" with the same-battleground
--     targeting note.
--   * Ablative Armour unit-defense description overstated the effect ("all
--     incoming DMG to 1"); it should read "Reduces direct attack DMG by 1."
--
-- The STRUCT_TYPE_SYNC_CS trigger only fires on struct_type writes, so after
-- editing struct_type_cs we explicitly burn the cheatsheet into struct_type.

BEGIN;

    UPDATE structs.struct_type_cs
       SET passive_weaponry_label       = 'Chimera Counter',
           passive_weaponry_description = 'Only targets Structs in the same Battleground.'
     WHERE class = 'Command Ship' AND language = 'EN';

    UPDATE structs.struct_type_cs
       SET unit_defenses_description = 'Reduces direct attack DMG by 1.'
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
