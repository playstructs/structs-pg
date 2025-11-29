-- Deploy structs-pg:table-struct-type-20251129-add-cheatsheet-details_data to pg

BEGIN;

    INSERT INTO structs.struct_type_cs VALUES('Command Ship','EN','','Chimera Missile','Only targets Structs in the same battleground.','Smart Weapon','','','Alpha Drift','Move the CMD Ship to another battleground.');
    INSERT INTO structs.struct_type_cs VALUES('Battleship','EN','','Mass Accelerator','','Ballistic Weapon','','','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Starfighter','EN','','Plasma Missile','','Smart Weapon','Attack Run','Ballistic Weapon','','');
    INSERT INTO structs.struct_type_cs VALUES('Frigate','EN','','RPTR Missile','','Smart Weapon','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Pursuit Fighter','EN','','Cloudstrike Missile','','Smart Weapon','','','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Stealth Bomber','EN','','Plasma Bomb','','Smart Weapon','','','Stealth Mode','When active, this Struct can only be targeted by units in the same battleground.');
    INSERT INTO structs.struct_type_cs VALUES('High Altitude Interceptor','EN','','RPTR Missile','','Smart Weapon','','','Kinetic Shield','Has a 1/3 chance to deflect incoming Ballistic Weapon attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Mobile Artillery','EN','','Artillery Strike','','Ballistic Weapon','','','Tactical Retreat','This Struct cannot be counter-attacked, but also cannot launch counter-attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Tank','EN','','Rail Gun','','Ballistic Weapon','','','Ablative Armour','Reduces all incoming DMG to 1.');
    INSERT INTO structs.struct_type_cs VALUES('SAM Launcher','EN','','RPTR Missile','','Smart Weapon','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Cruiser','EN','','Planetary Missile','','Smart Weapon','AA-Cannons','Ballistic Weapon','Signal Jamming','Has a 1/3 chance to deflect incoming Smart Weapon attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Destroyer','EN','','05-SPRY Missile','','Smart Weapon','','','Adv. Counter-Attack','Deals extra DMG to Structs in the same battleground.');
    INSERT INTO structs.struct_type_cs VALUES('Submersible','EN','','Voidreach Missile','','Smart Weapon','','','Stealth Mode','When active, this Struct can only be targeted by units in the same battleground.');
    INSERT INTO structs.struct_type_cs VALUES('Ore Extractor','EN','Extracts Alpha Ore from the planet.','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Ore Refinery','EN','Refines Ore into usable Alpha Matter.','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Orbital Shield Generator','EN','Improves Planetary Defense.','','','','','','Ore Shield','Projects a shield around Ore storage facilities, improving Planetary Defense.');
    INSERT INTO structs.struct_type_cs VALUES('Jamming Satellite','EN','Applies Signal Jamming to all enemy Smart Weapon Attacks.','','','','','','Planetary Signal Jamming','Has a 1/3 chance to deflect all enemy Smart Weapon attacks.');
    INSERT INTO structs.struct_type_cs VALUES('Ore Bunker','EN','Massively improves Planetary Defense by storing Ore underground.','','','','','','Fortified Storage','Ore is stored in a fortified underground facility.');
    INSERT INTO structs.struct_type_cs VALUES('Planetary Defense Cannon','EN','Launches Counter-Attacks against attacking Structs.','','','','','','Ultimate Deterrent','Mass accelerators intimidate pirates.');
    INSERT INTO structs.struct_type_cs VALUES('Field Generator','EN','Consumes Alpha Matter to generate Energy. Moderate efficiency.','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('Continental Power Plant','EN','Consumes Alpha Matter to generate Energy. High efficiency.','','','','','','','');
    INSERT INTO structs.struct_type_cs VALUES('World Engine','EN','Consumes Alpha Matter to generate Energy. Extra high efficiency.','','','','','','','');


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
