-- Deploy structs-pg:table-struct-type-20251202-add-cheatsheet-extended-details to pg

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
        drive_label TEXT,
        drive_description TEXT,
        passive_weaponry_label TEXT,
        passive_weaponry_description TEXT,
        unit_defenses_label TEXT,
        unit_defenses_description TEXT,
        ore_reserve_defenses_label TEXT,
        ore_reserve_defenses_description TEXT,
        planetary_defenses_label TEXT,
        planetary_defenses_description TEXT,
        planetary_mining_label TEXT,
        planetary_mining_description TEXT,
        planetary_refineries_label TEXT,
        planetary_refineries_description TEXT,
        power_generation_label TEXT,
        power_generation_description TEXT,
        PRIMARY KEY(class, language)
    );


    INSERT INTO structs.struct_type_cs VALUES('Command Ship','EN','','Chimera Missile','Only targets Structs in the same battleground.','Smart Weapon','','','Alpha Drift','Move the CMD Ship to another battleground.','Strong Counter-Attack','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Battleship','EN','','Mass Accelerator','','Ballistic Weapon','','','','','Counter-Attack','','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Starfighter','EN','','Plasma Missile','','Smart Weapon','Attack Run','Ballistic Weapon','','','Counter-Attack','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Frigate','EN','','RPTR Missile','','Smart Weapon','','','','','Counter-Attack','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Pursuit Fighter','EN','','Cloudstrike Missile','','Smart Weapon','','','','','Counter-Attack','','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Stealth Bomber','EN','','Plasma Bomb','','Smart Weapon','','','','','Counter-Attack','','Stealth Mode','When active, this Struct can only be targeted by units in the same battleground.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('High Altitude Interceptor','EN','','RPTR Missile','','Smart Weapon','','','','','Counter-Attack','','Kinetic Shield','Has a 1/3 chance to deflect incoming Ballistic Weapon attacks.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Mobile Artillery','EN','','Artillery Strike','','Ballistic Weapon','','','','','','','Tactical Retreat','This Struct cannot be counter-attacked, but also cannot launch counter-attacks.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Tank','EN','','Rail Gun','','Ballistic Weapon','','','','','Counter-Attack','','Ablative Armour','Reduces all incoming DMG to 1.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('SAM Launcher','EN','','RPTR Missile','','Smart Weapon','','','','','Counter-Attack','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Cruiser','EN','','Planetary Missile','','Smart Weapon','AA-Cannons','Ballistic Weapon','','','Counter-Attack','','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Destroyer','EN','','05-SPRY Missile','','Smart Weapon','','','','','Adv. Counter-Attack','Deals extra DMG to Structs in the same battleground.','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Submersible','EN','','Voidreach Missile','','Smart Weapon','','','','','Counter-Attack','','Stealth Mode','When active, this Struct can only be targeted by units in the same battleground.','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Ore Extractor','EN','Extracts Alpha Ore from the planet.','','','','','','','','','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Ore Refinery','EN','Refines Ore into usable Alpha Matter.','','','','','','','','','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Orbital Shield Generator','EN','Improves Planetary Defense.','','','','','','','','','','','','Ore Shield','Projects a shield around Ore storage facilities, improving Planetary Defense.','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Jamming Satellite','EN','Applies Signal Jamming to all enemy Smart Weapon Attacks.','','','','','','','','','','','','','','Planetary Signal Jamming','Has a 1/3 chance to deflect all enemy Smart Weapon attacks.','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Ore Bunker','EN','Massively improves Planetary Defense by storing Ore underground.','','','','','','','','','','','','Fortified Storage','Ore is stored in a fortified underground facility.','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Planetary Defense Cannon','EN','Launches Counter-Attacks against attacking Structs.','','','','','','','','','','','','','','Ultimate Deterrent','Mass accelerators intimidate pirates.','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Field Generator','EN','Consumes Alpha Matter to generate Energy. Moderate efficiency.','','','','','','','','','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Continental Power Plant','EN','Consumes Alpha Matter to generate Energy. High efficiency.','','','','','','','','','','','','','','','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('World Engine','EN','Consumes Alpha Matter to generate Energy. Extra high efficiency.','','','','','','','','','','','','','','','','','','','','','');

    ALTER TABLE structs.struct_type DROP COLUMN ability_label;
    ALTER TABLE structs.struct_type DROP COLUMN ability_description;

    ALTER TABLE structs.struct_type ADD COLUMN drive_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN drive_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN passive_weaponry_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN passive_weaponry_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN unit_defenses_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN unit_defenses_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN ore_reserve_defenses_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN ore_reserve_defenses_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN planetary_defenses_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN planetary_defenses_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN planetary_mining_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN planetary_mining_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN planetary_refineries_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN planetary_refineries_description TEXT;

    ALTER TABLE structs.struct_type ADD COLUMN power_generation_label TEXT;
    ALTER TABLE structs.struct_type ADD COLUMN power_generation_description TEXT;

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
