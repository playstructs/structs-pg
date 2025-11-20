-- Revert structs-pg:cache-trigger-add-queue-20251120-add-energy-precision-to-struct-type from pg

BEGIN;


CREATE OR REPLACE FUNCTION cache.ADD_QUEUE()
    RETURNS trigger AS
$BODY$
DECLARE
    body jsonb;
BEGIN
    IF NEW.composite_key = 'structs.structs.EventAllocation.allocation' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.allocation
        VALUES (
                       body->>'id',
                       body->>'type',

                       body->>'sourceObjectId',
                       (body->>'index')::INTEGER,
                       body->>'destinationId',

                       body->>'creator',
                       body->>'controller',
                       (body->>'locked')::BOOLEAN,
                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                destination_id = EXCLUDED.destination_id,
                controller = EXCLUDED.controller,
                locked = EXCLUDED.locked,
                updated_at = NOW();


    ELSIF NEW.composite_key = 'structs.structs.EventAgreement.agreement' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.agreement
        VALUES (
                       body->>'id',

                       body->>'providerId',
                       body->>'allocationId',

                       (body->>'capacity')::BIGINT,

                       (body->>'startBlock')::BIGINT,
                       (body->>'endBlock')::BIGINT,

                       body->>'creator',
                       body->>'owner',

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                capacity=EXCLUDED.capacity,
                start_block=EXCLUDED.start_block,
                end_block=EXCLUDED.end_block,
                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventGuild.guild' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.guild (id, index, endpoint, join_infusion_minimum_p, join_infusion_minimum_bypass_by_request, join_infusion_minimum_bypass_by_invite, primary_reactor_id, entry_substation_id,creator, owner, created_at, updated_at )
        VALUES (
                       body->>'id',
                       (body->>'index')::INTEGER,

                       body->>'endpoint',

                       (body->>'joinInfusionMinimum')::INTEGER,
                       body->>'joinInfusionMinimumBypassByRequest',
                       body->>'joinInfusionMinimumBypassByInvite',

                       body->>'primaryReactorId',
                       body->>'entrySubstationId',

                       body->>'creator',
                       body->>'owner',
                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                endpoint = EXCLUDED.endpoint,
                join_infusion_minimum_p = EXCLUDED.join_infusion_minimum_p,
                join_infusion_minimum_bypass_by_request = EXCLUDED.join_infusion_minimum_bypass_by_request,
                join_infusion_minimum_bypass_by_invite = EXCLUDED.join_infusion_minimum_bypass_by_invite,
                primary_reactor_id = EXCLUDED.primary_reactor_id,
                entry_substation_id = EXCLUDED.entry_substation_id,
                owner = EXCLUDED.owner,
                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventInfusion.infusion' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.infusion (destination_id, address, destination_type, player_id, fuel_p, defusing_p, power_p, ratio_p, commission, created_at, updated_at)
        VALUES (
                       body->>'destinationId',
                       body->>'address',

                       body->>'destinationType',
                       body->>'playerId',

                       (body->>'fuel')::NUMERIC,
                       (body->>'defusing')::NUMERIC,
                       (body->>'power')::NUMERIC,
                       (body->>'ratio')::NUMERIC,

                       (body->>'commission')::NUMERIC,

                       NOW(),
                       NOW()
               ) ON CONFLICT (destination_id, address) DO UPDATE
            SET
                fuel_p = EXCLUDED.fuel_p,
                defusing_p = EXCLUDED.defusing_p,
                power_p = EXCLUDED.power_p,
                ratio_p = EXCLUDED.ratio_p,
                commission = EXCLUDED.commission,
                updated_at = NOW();

    ELSIF NEW.composite_key = 'structs.structs.EventFleet.fleet' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.fleet
        VALUES (
                       body->>'id',
                       body->>'owner',

                       jsonb_build_object('space', body->'space') || jsonb_build_object('air', body->'air') || jsonb_build_object('land', body->'land') || jsonb_build_object('water', body->'water'),

                       (body->>'spaceSlots')::INTEGER,
                       (body->>'airSlots')::INTEGER,
                       (body->>'landSlots')::INTEGER,
                       (body->>'waterSlots')::INTEGER,

                       body->>'locationType',
                       body->>'locationId',
                       body->>'status',

                       body->>'locationListForward',
                       body->>'locationListBackward',

                       body->>'commandStruct',

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,

                map = jsonb_build_object('space', EXCLUDED.map->'space') || jsonb_build_object('air', EXCLUDED.map->'air') || jsonb_build_object('land', EXCLUDED.map->'land') || jsonb_build_object('water', EXCLUDED.map->'water'),

                location_type = EXCLUDED.location_type,
                location_id = EXCLUDED.location_id,
                status = EXCLUDED.status,

                location_list_forward = EXCLUDED.location_list_forward,
                location_list_backward = EXCLUDED.location_list_backward,

                command_struct = EXCLUDED.command_struct,

                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventPlanet.planet' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.planet
        VALUES (
                       body->>'id',
                       (body->>'maxOre')::INTEGER,
                       body->>'creator',
                       body->>'owner',
                       jsonb_build_object('space', body->'space') || jsonb_build_object('air', body->'air') || jsonb_build_object('land', body->'land') || jsonb_build_object('water', body->'water'),

                       (body->>'spaceSlots')::INTEGER,
                       (body->>'airSlots')::INTEGER,
                       (body->>'landSlots')::INTEGER,
                       (body->>'waterSlots')::INTEGER,

                       body->>'status',

                       body->>'locationListStart',
                       body->>'locationListEnd',

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,

                map = jsonb_build_object('space', EXCLUDED.map->'space') || jsonb_build_object('air', EXCLUDED.map->'air') || jsonb_build_object('land', EXCLUDED.map->'land') || jsonb_build_object('water', EXCLUDED.map->'water'),
                status = EXCLUDED.status,

                location_list_start = EXCLUDED.location_list_start,
                location_list_end = EXCLUDED.location_list_end,

                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventPlayer.player' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.player
        VALUES (
                       body->>'id',
                       (body->>'index')::INTEGER,
                       body->>'creator',
                       body->>'primaryAddress',

                       body->>'guildId',
                       body->>'substationId',
                       body->>'planetId',
                       body->>'fleetId',

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO
            UPDATE
            SET
                primary_address = EXCLUDED.primary_address,
                guild_id = EXCLUDED.guild_id,
                substation_id = EXCLUDED.substation_id,
                planet_id = EXCLUDED.planet_id,
                fleet_id = EXCLUDED.fleet_id,

                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'id') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventProvider.provider' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.provider
        VALUES (
                       body->>'id',
                       (body->>'index')::INTEGER,

                       body->>'substationId',

                       (body->'rate'->>'amount')::NUMERIC,
                       body->'rate'->>'denom',

                       body->>'accessPolicy',

                       (body->>'capacityMinimum')::NUMERIC,
                       (body->>'capacityMaximum')::NUMERIC,
                       (body->>'durationMinimum')::NUMERIC,
                       (body->>'durationMaximum')::NUMERIC,

                       (body->>'providerCancellationPenalty')::NUMERIC,
                       (body->>'consumerCancellationPenalty')::NUMERIC,


                       body->>'creator',
                       body->>'owner',

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                access_policy=EXCLUDED.access_policy,
                capacity_minimum=EXCLUDED.capacity_minimum,
                capacity_maximum=EXCLUDED.capacity_maximum,
                duration_minimum=EXCLUDED.duration_minimum,
                duration_maximum=EXCLUDED.duration_maximum,
                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventReactor.reactor' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.reactor
        VALUES (
                       body->>'id',
                       body->>'validator',
                       body->>'guildId',
                       (body->>'defaultCommission')::NUMERIC,
                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                guild_id = EXCLUDED.guild_id,
                default_commission = EXCLUDED.default_commission,
                updated_at = NOW();


    ELSIF NEW.composite_key = 'structs.structs.EventStruct.structure' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.struct
        VALUES (
                       body->>'id',
                       (body->>'index')::INTEGER,
                       (body->>'type')::INTEGER,

                       body->>'creator',
                       body->>'owner',

                       body->>'locationType',
                       body->>'locationId',
                       body->>'operatingAmbit',
                       (body->>'slot')::INTEGER,

                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,
                location_type = EXCLUDED.location_type,
                location_id = EXCLUDED.location_id,
                operating_ambit = EXCLUDED.operating_ambit,
                slot = EXCLUDED.slot,
                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventStructDefender.structDefender' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.struct_defender
        VALUES (
                       body->>'defendingStructId',
                       body->>'protectedStructId',
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                defending_struct_id = EXCLUDED.defending_struct_id,
                protected_struct_id = EXCLUDED.protected_struct_id,
                updated_at = EXCLUDED.updated_at;


    ELSIF NEW.composite_key = 'structs.structs.EventStructType.structType' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.struct_type(
            id,
            type,
            category,
            build_limit ,
            build_difficulty,
            build_draw, -- table-struct-type-meta-20251120-add-energy-precision updated this to build_draw_p
            max_health,
            passive_draw, -- table-struct-type-meta-20251120-add-energy-precision updated this to passive_draw_p
            possible_ambit,
            movable,
            slot_bound,
            primary_weapon,
            primary_weapon_control,
            primary_weapon_charge,
            primary_weapon_ambits,
            primary_weapon_targets,
            primary_weapon_shots,
            primary_weapon_damage,
            primary_weapon_blockable,
            primary_weapon_counterable,
            primary_weapon_recoil_damage,
            primary_weapon_shot_success_rate_numerator,
            primary_weapon_shot_success_rate_denominator,
            secondary_weapon,
            secondary_weapon_control,
            secondary_weapon_charge,
            secondary_weapon_ambits,
            secondary_weapon_targets,
            secondary_weapon_shots,
            secondary_weapon_damage,
            secondary_weapon_blockable,
            secondary_weapon_counterable,
            secondary_weapon_recoil_damage,
            secondary_weapon_shot_success_rate_numerator,
            secondary_weapon_shot_success_rate_denominator,
            passive_weaponry,
            unit_defenses,
            ore_reserve_defenses,
            planetary_defenses,
            planetary_mining ,
            planetary_refinery,
            power_generation,
            activate_charge,
            build_charge,
            defend_change_charge,
            move_charge,
            ore_mining_charge,
            ore_refining_charge,
            stealth_activate_charge,
            attack_reduction,
            attack_counterable,
            stealth_systems,
            counter_attack,
            counter_attack_same_ambit,
            post_destruction_damage,
            generating_rate,
            planetary_shield_contribution,
            ore_mining_difficulty,
            ore_refining_difficulty,
            unguided_defensive_success_rate_numerator,
            unguided_defensive_success_rate_denominator,
            guided_defensive_success_rate_numerator,
            guided_defensive_success_rate_denominator,
            trigger_raid_defeat_by_destruction,
            updated_at,
            --possible_ambit_array jsonb GENERATED
            class,
            class_abbreviation,
            default_cosmetic_model_number,
            default_cosmetic_name
            -- build_draw GENERATED
            -- passive_draw GENERATED
        )
        VALUES (
                   (body->>'id')::INTEGER,
                   body->>'type',

                   body->>'category',

                   (body->>'buildLimit')::INTEGER,
                   (body->>'buildDifficulty')::INTEGER,
                   (body->>'buildDraw')::INTEGER,
                   (body->>'maxHealth')::INTEGER,
                   (body->>'passiveDraw')::INTEGER,
                   (body->>'possibleAmbit')::INTEGER,

                   (body->>'movable')::BOOLEAN,
                   (body->>'slotBound')::BOOLEAN,


                   body->>'primaryWeapon',
                   body->>'primaryWeaponControl',
                   (body->>'primaryWeaponCharge')::INTEGER,
                   (body->>'primaryWeaponAmbits')::INTEGER,
                   (body->>'primaryWeaponTargets')::INTEGER,
                   (body->>'primaryWeaponShots')::INTEGER,
                   (body->>'primaryWeaponDamage')::INTEGER,
                   (body->>'primaryWeaponBlockable')::BOOLEAN,
                   (body->>'primaryWeaponCounterable')::BOOLEAN,
                   (body->>'primaryWeaponRecoilDamage')::INTEGER,
                   (body->>'primaryWeaponShotSuccessRateNumerator')::INTEGER,
                   (body->>'primaryWeaponShotSuccessRateDenominator')::INTEGER,

                   body->>'secondaryWeapon',
                   body->>'secondaryWeaponControl',
                   (body->>'secondaryWeaponCharge')::INTEGER,
                   (body->>'secondaryWeaponAmbits')::INTEGER,
                   (body->>'secondaryWeaponTargets')::INTEGER,
                   (body->>'secondaryWeaponShots')::INTEGER,
                   (body->>'secondaryWeaponDamage')::INTEGER,
                   (body->>'secondaryWeaponBlockable')::BOOLEAN,
                   (body->>'secondaryWeaponCounterable')::BOOLEAN,
                   (body->>'secondaryWeaponRecoilDamage')::INTEGER,
                   (body->>'secondaryWeaponShotSuccessRateNumerator')::INTEGER,
                   (body->>'secondaryWeaponShotSuccessRateDenominator')::INTEGER,


                   body->>'passiveWeaponry',
                   body->>'unitDefenses',
                   body->>'oreReserveDefenses',
                   body->>'planetaryDefenses',
                   body->>'planetaryMining',
                   body->>'planetaryRefinery',
                   body->>'powerGeneration',

                   (body->>'activateCharge')::INTEGER,
                   (body->>'buildCharge')::INTEGER,
                   (body->>'defendChangeCharge')::INTEGER,
                   (body->>'moveCharge')::INTEGER,
                   (body->>'oreMiningCharge')::INTEGER,
                   (body->>'oreRefiningCharge')::INTEGER,
                   (body->>'stealthActivateCharge')::INTEGER,

                   (body->>'attackReduction')::INTEGER,
                   (body->>'attackCounterable')::BOOLEAN,
                   (body->>'stealthSystems')::BOOLEAN,
                   (body->>'counterAttack')::INTEGER,
                   (body->>'counterAttackSameAmbit')::INTEGER,
                   (body->>'postDestructionDamage')::INTEGER,
                   (body->>'generatingRate')::INTEGER,
                   (body->>'planetaryShieldContribution')::INTEGER,
                   (body->>'oreMiningDifficulty')::INTEGER,
                   (body->>'oreRefiningDifficulty')::INTEGER,

                   (body->>'unguidedDefensiveSuccessRateNumerator')::INTEGER,
                   (body->>'unguidedDefensiveSuccessRateDenominator')::INTEGER,

                   (body->>'guidedDefensiveSuccessRateNumerator')::INTEGER,
                   (body->>'guidedDefensiveSuccessRateDenominator')::INTEGER,

                   (body->>'triggerRaidDefeatByDestruction')::BOOLEAN,

                   NOW(),
                   body->>'class',
                   body->>'classAbbreviation',
                   body->>'defaultCosmeticModelNumber',
                   body->>'defaultCosmeticName'
               ) ON CONFLICT (id) DO UPDATE
            SET
                type = EXCLUDED.type,
                category = EXCLUDED.category,
                build_limit = EXCLUDED.build_limit,
                build_difficulty = EXCLUDED.build_difficulty,
                build_draw = EXCLUDED.build_draw,
                max_health = EXCLUDED.max_health,
                passive_draw = EXCLUDED.passive_draw,
                possible_ambit = EXCLUDED.possible_ambit,
                movable = EXCLUDED.movable,
                slot_bound = EXCLUDED.slot_bound,
                primary_weapon = EXCLUDED.primary_weapon,
                primary_weapon_control = EXCLUDED.primary_weapon_control,
                primary_weapon_charge = EXCLUDED.primary_weapon_charge,
                primary_weapon_ambits = EXCLUDED.primary_weapon_ambits,
                primary_weapon_targets = EXCLUDED.primary_weapon_targets,
                primary_weapon_shots = EXCLUDED.primary_weapon_shots,
                primary_weapon_damage = EXCLUDED.primary_weapon_damage,
                primary_weapon_blockable = EXCLUDED.primary_weapon_blockable,
                primary_weapon_counterable = EXCLUDED.primary_weapon_counterable,
                primary_weapon_recoil_damage = EXCLUDED.primary_weapon_recoil_damage,
                primary_weapon_shot_success_rate_numerator = EXCLUDED.primary_weapon_shot_success_rate_numerator,
                primary_weapon_shot_success_rate_denominator = EXCLUDED.primary_weapon_shot_success_rate_denominator,
                secondary_weapon = EXCLUDED.secondary_weapon,
                secondary_weapon_control = EXCLUDED.secondary_weapon_control,
                secondary_weapon_charge = EXCLUDED.secondary_weapon_charge,
                secondary_weapon_ambits = EXCLUDED.secondary_weapon_ambits,
                secondary_weapon_targets = EXCLUDED.secondary_weapon_targets,
                secondary_weapon_shots = EXCLUDED.secondary_weapon_shots,
                secondary_weapon_damage = EXCLUDED.secondary_weapon_damage,
                secondary_weapon_blockable = EXCLUDED.secondary_weapon_blockable,
                secondary_weapon_counterable = EXCLUDED.secondary_weapon_counterable,
                secondary_weapon_recoil_damage = EXCLUDED.secondary_weapon_recoil_damage,
                secondary_weapon_shot_success_rate_numerator = EXCLUDED.secondary_weapon_shot_success_rate_numerator,
                secondary_weapon_shot_success_rate_denominator = EXCLUDED.secondary_weapon_shot_success_rate_denominator,
                passive_weaponry = EXCLUDED.passive_weaponry,
                unit_defenses = EXCLUDED.unit_defenses,
                ore_reserve_defenses = EXCLUDED.ore_reserve_defenses,
                planetary_defenses = EXCLUDED.planetary_defenses,
                planetary_mining = EXCLUDED.planetary_mining,
                planetary_refinery = EXCLUDED.planetary_refinery,
                power_generation = EXCLUDED.power_generation,
                activate_charge = EXCLUDED.activate_charge,
                build_charge = EXCLUDED.build_charge,
                defend_change_charge = EXCLUDED.defend_change_charge,
                move_charge = EXCLUDED.move_charge,
                ore_mining_charge = EXCLUDED.ore_mining_charge,
                ore_refining_charge = EXCLUDED.ore_refining_charge,
                stealth_activate_charge = EXCLUDED.stealth_activate_charge,
                attack_reduction = EXCLUDED.attack_reduction,
                attack_counterable = EXCLUDED.attack_counterable,
                stealth_systems = EXCLUDED.stealth_systems,
                counter_attack = EXCLUDED.counter_attack,
                counter_attack_same_ambit = EXCLUDED.counter_attack_same_ambit,
                post_destruction_damage = EXCLUDED.post_destruction_damage,
                generating_rate = EXCLUDED.generating_rate,
                planetary_shield_contribution = EXCLUDED.planetary_shield_contribution,
                ore_mining_difficulty = EXCLUDED.ore_mining_difficulty,
                ore_refining_difficulty = EXCLUDED.ore_refining_difficulty,
                unguided_defensive_success_rate_numerator = EXCLUDED.unguided_defensive_success_rate_numerator,
                unguided_defensive_success_rate_denominator = EXCLUDED.unguided_defensive_success_rate_denominator,
                guided_defensive_success_rate_numerator = EXCLUDED.guided_defensive_success_rate_numerator,
                guided_defensive_success_rate_denominator = EXCLUDED.guided_defensive_success_rate_denominator,
                trigger_raid_defeat_by_destruction = EXCLUDED.trigger_raid_defeat_by_destruction,
                updated_at = NOW(),
                class = EXCLUDED.class,
                class_abbreviation = EXCLUDED.class_abbreviation,
                default_cosmetic_model_number = EXCLUDED.default_cosmetic_model_number,
                default_cosmetic_model_number= EXCLUDED.default_cosmetic_name;



    ELSIF NEW.composite_key = 'structs.structs.EventSubstation.substation' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.substation
        VALUES (
                       body->>'id',
                       body->>'owner',
                       body->>'creator',
                       NOW(),
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,
                updated_at = NOW();

        INSERT INTO structs.player_object(object_id, player_id) VALUES(body->>'id',body->>'owner') ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id;

    ELSIF NEW.composite_key = 'structs.structs.EventGuildMembershipApplication.guildMembershipApplication' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.guild_membership_application
        VALUES (
                       body->>'guildId',
                       body->>'playerId',
                       body->>'joinType',
                       body->>'registrationStatus',
                       body->>'proposer',
                       body->>'substationId',
                       NOW(),
                       NOW()
               ) ON CONFLICT (guild_id, player_id) DO UPDATE
            SET
                join_type = EXCLUDED.join_type,
                status = EXCLUDED.status,
                proposer = EXCLUDED.proposer,
                substation_id = EXCLUDED.substation_id,
                updated_at = NOW();

        -- Make generic address association stuff happen
    ELSIF NEW.composite_key = 'structs.structs.EventAddressActivity.addressActivity' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.player_address_activity
        VALUES (
                       body->>'address',
                       (select player_address.player_id from structs.player_address where player_address.address = body->>'address'),
                       (body->>'blockHeight')::INTEGER,
                       (body->>'blockTime')::TIMESTAMPTZ
               ) ON CONFLICT (address) DO UPDATE
            SET
                block_height = EXCLUDED.block_height,
                block_time = EXCLUDED.block_time;


        -- Make generic address association stuff happen
    ELSIF NEW.composite_key = 'structs.structs.EventAddress.address' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.player_address
        VALUES (
                       body->>'address',
                       body->>'playerId',
                       (select guild_id from structs.player where player.id=body->>'playerId'),
                       'approved',
                       NOW(),
                       NOW()
               ) ON CONFLICT (address) DO UPDATE
            SET
                status = EXCLUDED.status,
                player_id = EXCLUDED.player_id,
                updated_at = EXCLUDED.updated_at;
        -- Make generic address association stuff happen
    ELSIF NEW.composite_key = 'structs.structs.EventAddressAssociation.addressAssociation' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.player_address
        VALUES (
                       body->>'address',
                       '1-' || (body->>'playerIndex')::CHARACTER VARYING, -- cast the index into the proper player account ID
                       (select guild_id from structs.player where player.id=('1-' || (body->>'playerIndex')::CHARACTER VARYING)),
                       body->>'registrationStatus',
                       NOW(),
                       NOW()
               ) ON CONFLICT (address) DO UPDATE
            SET
                status = EXCLUDED.status,
                player_id = EXCLUDED.player_id,
                updated_at = EXCLUDED.updated_at;

        -- Make generic permission stuff happen
    ELSIF NEW.composite_key = 'structs.structs.EventPermission.permissionRecord' THEN
        body := (NEW.value)::jsonb;

        IF body->>'value' = '' THEN
            DELETE FROM structs.permission WHERE id = body->>'permissionId';
        ELSE

            INSERT INTO structs.permission
            VALUES (
                           body->>'permissionId',
                       -- object_type INTEGER,
                           CASE split_part(body->>'permissionId','-',1)
                               WHEN '0' THEN 'guild'
                               WHEN '1' THEN 'player'
                               WHEN '2' THEN 'planet'
                               WHEN '3' THEN 'reactor'
                               WHEN '4' THEN 'substation'
                               WHEN '5' THEN 'struct'
                               WHEN '6' THEN 'allocation'
                               WHEN '7' THEN 'infusion'
                               WHEN '8' THEN 'address'
                               WHEN '9' THEN 'fleet'
                               WHEN '10' THEN 'provider'
                               WHEN '11' THEN 'agreement'
                               END,
                           split_part(split_part(body->>'permissionId','-',2),'@',1),  -- object_index CHARACTER VARYING,

                           CASE split_part(body->>'permissionId','-',1)
                               WHEN '8' THEN (SELECT player_address.player_id FROM structs.player_address WHERE player_address.address = split_part(split_part(body->>'permissionId','-',2),'@',1))
                               ELSE split_part(body->>'permissionId','@',1)
                               END,                                                        -- object_id    CHARACTER VARYING,

                           CASE split_part(body->>'permissionId','-',1)
                               WHEN '8' THEN (SELECT player_address.player_id FROM structs.player_address WHERE player_address.address = split_part(split_part(body->>'permissionId','-',2),'@',1))
                               ELSE split_part(body->>'permissionId','@',2)
                               END,                                                        -- player_id    CHARACTER VARYING,

                           (body->>'value')::INTEGER,
                           NOW()
                   ) ON CONFLICT (id) DO UPDATE
                SET
                    val = EXCLUDED.val,
                    updated_at = EXCLUDED.updated_at;
        END IF;
        -- make generic grid stuff happen
    ELSIF NEW.composite_key = 'structs.structs.EventGrid.gridRecord' THEN
        body := (NEW.value)::jsonb;

        IF body->>'value' = '' THEN
            DELETE FROM structs.grid WHERE id = body->>'attributeId';

            CASE split_part(body->>'attributeId', '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '1' THEN
                    INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '2' THEN
                    INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '3' THEN
                    INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '4' THEN
                    INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '5' THEN
                    INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '6' THEN
                    INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '7' THEN
                    INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                ELSE

                END CASE;
        ELSE

            INSERT INTO structs.grid
            VALUES (
                           body->>'attributeId',

                       --  attribute_type  CHARACTER VARYING,
                           CASE split_part(body->>'attributeId', '-',1)
                               WHEN '0' THEN 'ore'
                               WHEN '1' THEN 'fuel'
                               WHEN '2' THEN 'capacity'
                               WHEN '3' THEN 'load'
                               WHEN '4' THEN 'structsLoad'
                               WHEN '5' THEN 'power'
                               WHEN '6' THEN 'connectionCapacity'
                               WHEN '7' THEN 'connectionCount'
                               WHEN '8' THEN 'allocationPointerStart'
                               WHEN '9' THEN 'allocationPointerEnd'
                               WHEN '10' THEN 'proxyNonce'
                               WHEN '11' THEN 'lastAction'
                               WHEN '12' THEN 'nonce'
                               WHEN '13' THEN 'ready'
                               WHEN '14' THEN 'checkpointBlock'
                               END,

                       -- object_type   CHARACTER VARYING,
                           CASE split_part(body->>'attributeId', '-', 2)
                               WHEN '0' THEN 'guild'
                               WHEN '1' THEN 'player'
                               WHEN '2' THEN 'planet'
                               WHEN '3' THEN 'reactor'
                               WHEN '4' THEN 'substation'
                               WHEN '5' THEN 'struct'
                               WHEN '6' THEN 'allocation'
                               WHEN '7' THEN 'infusion'
                               WHEN '8' THEN 'address'
                               WHEN '9' THEN 'fleet'
                               WHEN '10' THEN 'provider'
                               WHEN '11' THEN 'agreement'
                               END,

                       -- object_index  INTEGER,
                           (split_part(body->>'attributeId', '-', 3))::INTEGER,
                       -- object_id CHARACTER VARYING,
                           split_part(body->>'attributeId', '-', 2) || '-' || split_part(body->>'attributeId', '-', 3),

                           (body->>'value')::INTEGER,
                           NOW()
                   ) ON CONFLICT (id) DO UPDATE
                SET
                    val = EXCLUDED.val,
                    updated_at = EXCLUDED.updated_at;


            CASE split_part(body->>'attributeId', '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '1' THEN
                    INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '2' THEN
                    INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '3' THEN
                    INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '4' THEN
                    INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '5' THEN
                    INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(body->>'attributeId', '-', 2))::INTEGER), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '6' THEN
                    INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '7' THEN
                    INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                ELSE

                END CASE;

        END IF;


    ELSIF NEW.composite_key = 'structs.structs.EventStructAttribute.structAttributeRecord' THEN
        body := (NEW.value)::jsonb;

        IF body->>'value' = '' THEN
            DELETE FROM structs.struct_attribute WHERE id = body->>'attributeId';

            CASE split_part(body->>'attributeId', '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                WHEN '1' THEN
                    INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, 0);
                ELSE
                END CASE;
        ELSE

            INSERT INTO structs.struct_attribute
            VALUES (
                           body->>'attributeId',

                       -- object_id       CHARACTER VARYING,
                           split_part(body->>'attributeId', '-', 2) || '-' || split_part(body->>'attributeId', '-', 3),
                       -- object_type
                           CASE split_part(body->>'attributeId', '-', 2)
                               WHEN '0' THEN 'guild'
                               WHEN '1' THEN 'player'
                               WHEN '2' THEN 'planet'
                               WHEN '3' THEN 'reactor'
                               WHEN '4' THEN 'substation'
                               WHEN '5' THEN 'struct'
                               WHEN '6' THEN 'allocation'
                               WHEN '7' THEN 'infusion'
                               WHEN '8' THEN 'address'
                               WHEN '9' THEN 'fleet'
                               WHEN '10' THEN 'provider'
                               WHEN '11' THEN 'agreement'
                               END,
                       -- sub_index
                           CASE split_part(body->>'attributeId', '-', 4) WHEN '' THEN 0 ELSE (split_part(body->>'attributeId', '-', 4))::INTEGER END,

                       -- attribute_type  CHARACTER VARYING,
                           CASE split_part(body->>'attributeId', '-', 1)
                               WHEN '0' THEN 'health'
                               WHEN '1' THEN 'status'
                               WHEN '2' THEN 'blockStartBuild'
                               WHEN '3' THEN 'blockStartOreMine'
                               WHEN '4' THEN 'blockStartOreRefine'
                               WHEN '5' THEN 'protectedStructIndex'
                               WHEN '6' THEN 'typeCount'
                               END,
                           (body->>'value')::INTEGER,
                           NOW()
                   ) ON CONFLICT (id) DO UPDATE
                SET
                    val = EXCLUDED.val,
                    updated_at = EXCLUDED.updated_at;


            CASE split_part(body->>'attributeId', '-',1)
                WHEN '0' THEN
                    INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                WHEN '1' THEN
                    INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(body->>'attributeId', '-', 3))::INTEGER, (body->>'value')::INTEGER);
                ELSE
                END CASE;

        END IF;

    ELSIF NEW.composite_key = 'structs.structs.EventPlanetAttribute.planetAttributeRecord' THEN
        body := (NEW.value)::jsonb;

        IF body->>'value' = '' THEN
            DELETE FROM structs.planet_attribute WHERE id = body->>'attributeId';
        ELSE

            INSERT INTO structs.planet_attribute
            VALUES (
                           body->>'attributeId',
                       -- object_id       CHARACTER VARYING,
                           split_part(body->>'attributeId', '-', 2) || '-' || split_part(body->>'attributeId', '-', 3),
                       -- object_type
                           CASE split_part(body->>'attributeId', '-', 2)
                               WHEN '0' THEN 'guild'
                               WHEN '1' THEN 'player'
                               WHEN '2' THEN 'planet'
                               WHEN '3' THEN 'reactor'
                               WHEN '4' THEN 'substation'
                               WHEN '5' THEN 'struct'
                               WHEN '6' THEN 'allocation'
                               WHEN '7' THEN 'infusion'
                               WHEN '8' THEN 'address'
                               WHEN '9' THEN 'fleet'
                               WHEN '10' THEN 'provider'
                               WHEN '11' THEN 'agreement'
                               END,

                       -- attribute_type  CHARACTER VARYING,
                           CASE split_part(body->>'attributeId', '-', 1)
                               WHEN '0' THEN 'planetaryShield'
                               WHEN '1' THEN 'repairNetworkQuantity'
                               WHEN '2' THEN 'defensiveCannonQuantity'
                               WHEN '3' THEN 'coordinatedGlobalShieldNetworkQuantity'
                               WHEN '4' THEN 'lowOrbitBallisticsInterceptorNetworkQuantity'
                               WHEN '5' THEN 'advancedLowOrbitBallisticsInterceptorNetworkQuantity'
                               WHEN '6' THEN 'lowOrbitBallisticsInterceptorNetworkSuccessRateNumerator'
                               WHEN '7' THEN 'lowOrbitBallisticsInterceptorNetworkSuccessRateDenominator'
                               WHEN '8' THEN 'orbitalJammingStationQuantity'
                               WHEN '9' THEN 'advancedOrbitalJammingStationQuantity'
                               WHEN '10' THEN 'blockStartRaid'
                               END,
                           (body->>'value')::INTEGER,
                           NOW()
                   ) ON CONFLICT (id) DO UPDATE
                SET
                    val = EXCLUDED.val,
                    updated_at = EXCLUDED.updated_at;
        END IF;

    ELSIF NEW.composite_key = 'structs.structs.EventAttack.eventAttackDetail' THEN
        body := (NEW.value)::jsonb;

        WITH r_location AS (
            SELECT structs.GET_ACTIVITY_LOCATION_ID(body->>'attackerStructId') as location_id
        )
        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
        SELECT
            NOW(),
            structs.GET_PLANET_ACTIVITY_SEQUENCE(r_location.location_id),
            r_location.location_id,
            'struct_attack',
            body
        FROM r_location;

    ELSIF NEW.composite_key = 'structs.structs.EventOreMine.eventOreMineDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'primaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'mined', 'credit', 'ore');

    ELSIF NEW.composite_key = 'structs.structs.EventOreMigrate.eventOreMigrateDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'primaryAddress', body->>'oldPrimaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1),NOW(), 'migrated', 'credit', 'ore');


        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'oldPrimaryAddress', body->>'primaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'migrated', 'debit', 'ore');


    ELSIF NEW.composite_key = 'structs.structs.EventOreTheft.eventOreTheftDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'thiefPrimaryAddress', body->>'victimPrimaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'seized', 'credit', 'ore');


        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'victimPrimaryAddress', body->>'thiefPrimaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'forfeited', 'debit', 'ore');


    ELSIF NEW.composite_key = 'structs.structs.EventAlphaRefine.eventAlphaRefineDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'primaryAddress', (body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'debit', 'ore');


        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
        VALUES( body->>'primaryAddress', 1000000*(body->>'amount')::NUMERIC, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'credit', 'ualpha');

    ELSIF NEW.composite_key = 'structs.structs.EventRaid.eventRaidDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.planet_raid (fleet_id, planet_id, status, updated_at)
        VALUES (
                       body->>'fleetId',
                       body->>'planetId',
                       body->>'status',
                       NOW()
               ) ON CONFLICT (planet_id) DO UPDATE
            SET
                fleet_id = EXCLUDED.fleet_id,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at;

    ELSIF NEW.composite_key = 'structs.structs.EventTime.eventTimeDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.current_block VALUES ('testnet', (body->>'blockHeight')::BIGINT, (body->>'blockTime')::TIMESTAMPTZ)
        ON CONFLICT (chain) DO UPDATE SET height = EXCLUDED.height, updated_at = EXCLUDED.updated_at;


    ELSIF NEW.composite_key = 'structs.structs.EventProviderAddress.eventProviderAddressDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.address_tag (address, label, entry, updated_at, created_at)
        VALUES (
                       body->>'collateralPool',
                       'Type',
                       'Provider Collateral Pool',
                       NOW(),
                       NOW()
               ),
               (
                       body->>'collateralPool',
                       'ProviderId',
                       body->>'providerId',
                       NOW(),
                       NOW()
               ),
               (
                       body->>'earningPool',
                       'Type',
                       'Provider Earning Pool',
                       NOW(),
                       NOW()
               ),
               (
                       body->>'earningPool',
                       'ProviderId',
                       body->>'providerId',
                       NOW(),
                       NOW()
               )
        ON CONFLICT (address, label) DO UPDATE
            SET
                entry = EXCLUDED.entry,
                updated_at = EXCLUDED.updated_at;


    ELSIF NEW.composite_key = 'structs.structs.EventGuildBankAddress.eventGuildBankAddressDetail' THEN
        body := (NEW.value)::jsonb;

        INSERT INTO structs.address_tag (address, label, entry, updated_at, created_at)
        VALUES (
                       body->>'bankCollateralPool',
                       'Type',
                       'Bank Collateral Pool',
                       NOW(),
                       NOW()
               ),
               (
                       body->>'bankCollateralPool',
                       'GuildId',
                       body->>'guildId',
                       NOW(),
                       NOW()
               )
        ON CONFLICT (address, label) DO UPDATE
            SET
                entry = EXCLUDED.entry,
                updated_at = EXCLUDED.updated_at;

    END IF;
    RETURN NEW;
END
$BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                     COST 100;

COMMIT;
