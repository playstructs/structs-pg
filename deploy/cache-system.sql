-- Deploy structs-pg:cache-system to pg

BEGIN;

    /*
      This file defines the database schema for the PostgresQL ("psql") event sink
      implementation in Tendermint. The operator must create a database and install
      this schema before using the database to index events.
     */

    CREATE SCHEMA cache;

    -- The blocks table records metadata about each block.
    -- The block record does not include its events or transactions (see tx_results).
    CREATE UNLOGGED TABLE cache.blocks (
      rowid      BIGSERIAL PRIMARY KEY,

      height     BIGINT NOT NULL,
      chain_id   VARCHAR NOT NULL,

      -- When this block header was logged into the sink, in UTC.
      created_at TIMESTAMPTZ NOT NULL,

      UNIQUE (height, chain_id)
    );

    -- Index blocks by height and chain, since we need to resolve block IDs when
    -- indexing transaction records and transaction events.
    CREATE INDEX idx_blocks_height_chain ON cache.blocks(height, chain_id);
    CREATE INDEX idx_blocks_height ON cache.blocks(height);
    CREATE INDEX idx_blocks_rowid ON cache.blocks(rowid);

    -- The tx_results table records metadata about transaction results.  Note that
    -- the events from a transaction are stored separately.
    CREATE UNLOGGED TABLE cache.tx_results (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block to which this transaction belongs.
      block_id BIGINT NOT NULL REFERENCES cache.blocks(rowid) ON DELETE CASCADE,
      -- The sequential index of the transaction within the block.
      index INTEGER NOT NULL,
      -- When this result record was logged into the sink, in UTC.
      created_at TIMESTAMPTZ NOT NULL,
      -- The hex-encoded hash of the transaction.
      tx_hash VARCHAR NOT NULL,
      -- The protobuf wire encoding of the TxResult message.
      tx_result BYTEA NOT NULL,

      UNIQUE (block_id, index)
    ) ;

    --CREATE OR REPLACE VIEW cache.tx_results AS SELECT * FROM cache.tx_results_tbl;
    --CREATE OR REPLACE RULE block_tx_results AS ON INSERT to cache.tx_results DO INSTEAD NOTHING;


    -- The events table records events. All events (both block and transaction) are
    -- associated with a block ID; transaction events also have a transaction ID.
    CREATE UNLOGGED TABLE cache.events (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block and transaction this event belongs to.
      -- If tx_id is NULL, this is a block event.
      block_id BIGINT NOT NULL REFERENCES cache.blocks(rowid) ON DELETE CASCADE,
      tx_id    BIGINT NULL,

      -- The application-defined type label for the event.
      type VARCHAR NOT NULL
    );

    CREATE INDEX events_block ON cache.events(block_id);

    -- The attributes table records event attributes.
    CREATE UNLOGGED TABLE cache.attributes (
       event_id      BIGINT NOT NULL REFERENCES cache.events(rowid) ON DELETE CASCADE,
       key           VARCHAR NOT NULL, -- bare key
       composite_key VARCHAR NOT NULL, -- composed type.key
       value         VARCHAR NULL,
       UNIQUE (event_id, key)
    );

    CREATE INDEX attribute_event_key ON cache.attributes(event_id , composite_key);

    CREATE TABLE cache.attributes_tmp (
      composite_key VARCHAR NOT NULL, -- composed type.key
      value         VARCHAR NULL
    );

    --CREATE OR REPLACE VIEW cache.attributes AS SELECT * FROM cache.attributes_tbl;

    CREATE TABLE cache.queue (
        channel CHARACTER VARYING,
        id CHARACTER VARYING,
        CONSTRAINT queue_unique UNIQUE (channel, id)
    );

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
                   body->>'controller',

                   NOW(),
                   NOW()
             ) ON CONFLICT (id) DO UPDATE
                SET
                    capacity=EXLCUDED.capacity,
                    start_block=EXCLUDED.start_block,
                    end_block=EXCLUDED.end_block,
                    updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.structs.EventGuild.guild' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.guild
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
                        join_infusion_minimum = EXCLUDED.join_infusion_minimum,
                        join_infusion_minimum_bypass_by_request = EXCLUDED.join_infusion_minimum_bypass_by_request,
                        join_infusion_minimum_bypass_by_invite = EXCLUDED.join_infusion_minimum_bypass_by_invite,
                        primary_reactor_id = EXCLUDED.primary_reactor_id,
                        entry_substation_id = EXCLUDED.entry_substation_id,
                        owner = EXCLUDED.owner,
                        updated_at = NOW();


        ELSIF NEW.composite_key = 'structs.structs.EventInfusion.infusion' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.infusion
                VALUES (
                    body->>'destinationId',
                    body->>'address',

                    body->>'destinationType',
                    body->>'playerId',

                    (body->>'fuel')::INTEGER,
                    (body->>'defusing')::INTEGER,
                    (body->>'power')::INTEGER,
                    (body->>'ratio')::INTEGER,

                    (body->>'commission')::NUMERIC,

                    NOW(),
                    NOW()
                ) ON CONFLICT (destination_id, address) DO UPDATE
                    SET
                        fuel = EXCLUDED.fuel,
                        defusing = EXCLUDED.defusing,
                        power = EXCLUDED.power,
                        ratio = EXCLUDED.ratio,
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

                updated_at = NOW();


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

        ELSIF NEW.composite_key = 'structs.structs.EventProvider.provider' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.provider
                VALUES (
                    body->>'id',
                    (body->>'index')::INTEGER,

                    body->>'substationId',

                    (body->>'rateAmount')::BIGINT,
                    body->>'rateDenom',

                    body->>'accessPolicy',

                    (body->>'capacityMinimum')::BIGINT,
                    (body->>'capacityMaximum')::BIGINT,
                    (body->>'durationMinimum')::BIGINT,
                    (body->>'durationMaximum')::BIGINT,

                    (body->>'providerCancellationPenalty')::NUMERIC,
                    (body->>'consumerCancellationPenalty')::NUMERIC,


                    body->>'creator',
                    body->>'controller',

                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        access_policy=EXLCUDED.access_policy,
                        capacity_minimum=EXCLUDED.capacity_minimum,
                        capacity_maximum=EXCLUDED.capacity_maximum,
                        duration_minimum=EXCLUDED.duration_minimum,
                        duration_maximum=EXCLUDED.duration_maximum,
                        updated_at = NOW();


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

            INSERT INTO structs.struct_type
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

                           NOW()
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
                updated_at = NOW();



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

            INSERT INTO structs.ledger(address, amount, block_height, time, action, direction, denom)
                VALUES( body->>'primaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'mined', 'credit', 'ore');


        ELSIF NEW.composite_key = 'structs.structs.EventOreMigrate.eventOreMigrateDetail' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( body->>'primaryAddress', body->>'oldPrimaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1),NOW(), 'migrated', 'credit', 'ore');


            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( body->>'oldPrimaryAddress', body->>'primaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'migrated', 'debit', 'ore');


        ELSIF NEW.composite_key = 'structs.structs.EventOreTheft.eventOreTheftDetail' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( body->>'thiefPrimaryAddress', body->>'victimPrimaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'seized', 'credit', 'ore');


            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( body->>'victimPrimaryAddress', body->>'thiefPrimaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'forfeited', 'debit', 'ore');


        ELSIF NEW.composite_key = 'structs.structs.EventAlphaRefine.eventAlphaRefineDetail' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.ledger(address, amount, block_height, time, action, direction, denom)
                VALUES( body->>'primaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'debit', 'ore');


            INSERT INTO structs.ledger(address, amount, block_height, time, action, direction, denom)
                VALUES( body->>'primaryAddress', body->>'amount', (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'credit', 'alpha');

        ELSIF NEW.composite_key = 'structs.structs.EventRaid.eventRaidDetail' THEN
            body := (NEW.value)::jsonb;


            INSERT INTO structs.planet_raid (fleet_id, planet_id, status, created_at)
            VALUES (
                       body->>'fleetId',
                       body->>'planetId',
                       body->>'status',
                       NOW()
                   );

        ELSIF NEW.composite_key = 'structs.structs.EventTime.eventTimeDetail' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.current_block VALUES ('testnet', (body->>'blockHeight')::BIGINT, (body->>'blockTime')::TIMESTAMPTZ)
                ON CONFLICT (chain) DO UPDATE SET height = EXCLUDED.height, updated_at = EXCLUDED.updated_at;

        END IF;
        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.attributes
     FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

    CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.attributes_tmp
    FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();


    -- Used by the manual update script
    create table cache.tmp_json (data jsonb);


    -- Pruning try
    CREATE OR REPLACE PROCEDURE cache.CLEAN_QUEUE()
    AS
    $BODY$
    BEGIN

        -- The 2,000 number here was pulled roughly out of an ass
        -- Previous attempt was 1,000 and it appeared to result in orphaned attributes
        DELETE FROM cache.blocks where rowid in (select rowid FROM cache.blocks order by height desc offset 2000 FOR UPDATE SKIP LOCKED);

    END
    $BODY$
    LANGUAGE plpgsql SECURITY DEFINER;


    CREATE OR REPLACE FUNCTION cache.UDPATE_ADDRESS_GUILD()
            RETURNS trigger AS
        $BODY$
    BEGIN
        IF NEW.guild_id <> OLD.guild_ID THEN
            UPDATE structs.player_address SET guild_id = NEW.guild_id WHERE player_id = NEW.id;
        END IF;
    RETURN NEW;
    END
        $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER UPDATE_ADDRESS_GUILD_ID AFTER UPDATE ON structs.player
        FOR EACH ROW EXECUTE PROCEDURE cache.UDPATE_ADDRESS_GUILD();



    CREATE OR REPLACE FUNCTION cache.TRANSFER_LEDGER_ENTRY()
        RETURNS trigger AS
    $BODY$
    DECLARE
        entries RECORD;

        recipient CHARACTER VARYING;
        sender CHARACTER VARYING;
        amount CHARACTER VARYING;
        denom structs.denom;
    BEGIN
        FOR entries IN select event_id from cache.attributes where event_id in (select rowid from cache.events where block_id = (select rowid from cache.blocks where height = (NEW.height - 1))) and composite_key = 'transfer.amount' and value <> '' LOOP

            SELECT (regexp_matches(attributes.value, '(^[0-9\.]+)([a-zA-Z]+)'))[1]::INTEGER, (regexp_matches(attributes.value, '(^[0-9\.]+)([a-zA-Z]+)'))[2]::structs.denom INTO amount, denom     FROM cache.attributes WHERE attributes.event_id = entries.event_id AND composite_key = 'transfer.amount';

            SELECT attributes.value INTO recipient  FROM cache.attributes WHERE attributes.event_id = entries.event_id AND composite_key = 'transfer.recipient';
            SELECT attributes.value INTO sender     FROM cache.attributes WHERE attributes.event_id = entries.event_id AND composite_key = 'transfer.sender';

            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( sender, recipient, ((regexp_split_to_array(amount,'[a-z]'))[1])::BIGINT, (NEW.height -1), NOW(), 'sent', 'debit', denom);

            INSERT INTO structs.ledger(address, counterparty, amount, block_height, time, action, direction, denom)
                VALUES( recipient, sender, ((regexp_split_to_array(amount,'[a-z]'))[1])::BIGINT, (NEW.height -1), NOW(), 'received', 'credit', denom);
        END LOOP;

    RETURN NEW;
    END
        $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER TRANSFER_LEDGER_ENTRY AFTER INSERT ON cache.blocks
        FOR EACH ROW EXECUTE PROCEDURE cache.TRANSFER_LEDGER_ENTRY();



    CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_STRUCT_MOVEMENT() RETURNS trigger AS
    $BODY$
    DECLARE
        location_id CHARACTER VARYING;
    BEGIN
        IF
            NEW.location_id <> OLD.location_id
            OR NEW.operating_ambit <> OLD.operating_ambit
            OR NEW.slot <> OLD.slot
        THEN
            IF NEW.location_type = 'fleet' THEN
                SELECT fleet.location_id INTO location_id FROM structs.fleet where fleet.id = NEW.location_id;
            END IF;

            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(COALESCE(location_id, NEW.location_id)), COALESCE(location_id, NEW.location_id), 'struct_move',
                        jsonb_build_object( 'struct_id', NEW.id,
                                            'location_type', NEW.location_type,
                                            'location_id', NEW.location_id,
                                            'ambit', NEW.operating_ambit,
                                            'slot', NEW.slot)
                );

        END IF;
        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLANET_ACTIVITY_STRUCT_MOVEMENT AFTER UPDATE ON structs.struct
        FOR EACH ROW EXECUTE PROCEDURE cache.PLANET_ACTIVITY_STRUCT_MOVEMENT();



    CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_RAID_STATUS() RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(NEW.planet_id), NEW.planet_id, 'raid_status',
                jsonb_build_object( 'fleet_id', NEW.fleet_id,
                                'status', NEW.status)
        );
        RETURN NEW;
    END
        $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLANET_ACTIVITY_RAID_STATUS AFTER INSERT OR UPDATE ON structs.planet_raid
        FOR EACH ROW EXECUTE PROCEDURE cache.PLANET_ACTIVITY_RAID_STATUS();



    CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_FLEET_MOVE() RETURNS trigger AS
        $BODY$
    DECLARE
        old_move_detail jsonb;
        new_move_detail jsonb;
    BEGIN

        IF OLD.location_id IS NOT NULL AND OLD.location_id <> '' AND (OLD.location_id <> NEW.location_id) THEN

            old_move_detail := jsonb_build_object( 'fleet_id', OLD.id, 'fleet_status', OLD.status );
            IF OLD.status = 'away' THEN
                -- Add a list of fleets
               WITH RECURSIVE r_fleets AS (
                    SELECT id, location_list_backward
                    FROM fleet
                    WHERE location_id = OLD.location_id and location_list_forward = '' and status = 'away'
                    UNION
                    SELECT
                        e.id,
                        e.location_list_backward
                    FROM
                        fleet e
                            INNER JOIN r_fleets s ON s.location_list_backward = e.id
                )
                SELECT jsonb_build_object('fleet_list', array_to_json(array_agg(id))) || old_move_detail INTO old_move_detail FROM r_fleets;

            END IF;

            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(NEW.location_id),  OLD.location_id, 'fleet_depart', old_move_detail );

            new_move_detail := jsonb_build_object( 'fleet_id', NEW.id, 'fleet_status', NEW.status);
            IF NEW.status = 'away' THEN
                -- Add a list of fleets
               WITH RECURSIVE r_fleets AS (
                    SELECT id, location_list_backward
                    FROM fleet
                    WHERE location_id = NEW.location_id and location_list_forward = '' and status = 'away'
                    UNION
                    SELECT
                        e.id,
                        e.location_list_backward
                    FROM
                        fleet e
                            INNER JOIN r_fleets s ON s.location_list_backward = e.id
                    )
                    SELECT jsonb_build_object('fleet_list', array_to_json(array_agg(id))) || new_move_detail INTO old_move_detail FROM r_fleets;
            END IF;


            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(NEW.location_id), NEW.location_id, 'fleet_arrive', new_move_detail);


        END IF;

    RETURN NEW;
    END
            $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLANET_ACTIVITY_FLEET_MOVE AFTER INSERT OR UPDATE ON structs.fleet
       FOR EACH ROW EXECUTE PROCEDURE cache.PLANET_ACTIVITY_FLEET_MOVE();



CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_STRUCT_ATTRIBUTE() RETURNS trigger AS
    $BODY$
    DECLARE
        location_id CHARACTER VARYING;
    BEGIN

        IF TG_OP = 'DELETE' THEN
            CASE NEW.attribute_type
                WHEN 'typeCount' THEN
                    -- Nothing to do here

                WHEN 'protectedStructIndex' THEN
                    -- OLD.val - Struct Index no longer being protected
                    -- NEW.val - Struct Index now being protected
                    -- NEW.object_id - Defending Struct ID

                    -- We're going to project this activity on the planet of the protected Struct(s)

                    IF COALESCE(OLD.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || OLD.val) INTO location_id;
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_remove',
                                jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                                    'protected_struct_id', '5-' || OLD.val)
                               );
                    END IF;

                WHEN 'status' THEN
                    -- Shouldn't need a final status emit

                WHEN 'health' THEN
                    -- Health is covered via the battle actions

                WHEN 'blockStartBuild' THEN
                    -- Covered by Status changes to offline

                WHEN 'blockStartOreMine' THEN
                    -- Covered by Status changes to offline

                WHEN 'blockStartOreRefine' THEN
                    -- Covered by Status changes to offline
            END CASE;

        ELSE -- Insert and Update

            CASE NEW.attribute_type
                WHEN 'typeCount' THEN
                    -- Nothing to do here

                WHEN 'protectedStructIndex' THEN
                    -- OLD.val - Struct Index no longer being protected
                    -- NEW.val - Struct Index now being protected
                    -- NEW.object_id - Defending Struct ID

                    -- We're going to project this activity on the planet of the protected Struct(s)

                    IF COALESCE(OLD.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || OLD.val) INTO location_id;
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_remove',
                                jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                    'protected_struct_id', '5-' || OLD.val)
                            );
                    END IF;

                    IF COALESCE(NEW.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || NEW.val) INTO location_id;
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_add',
                                jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                                    'protected_struct_id', '5-' || NEW.val)
                               );
                    END IF;

                WHEN 'status' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_status',
                            jsonb_build_object( 'struct_id', NEW.object_id,
                                                'status', NEW.val)
                           );

                WHEN 'health' THEN
                   -- Health is covered via the battle actions

                WHEN 'blockStartBuild' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_build_start',
                            jsonb_build_object( 'struct_id', NEW.object_id,
                                                'block', NEW.val)
                           );

                WHEN 'blockStartOreMine' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_ore_mine_start',
                            jsonb_build_object( 'struct_id', NEW.object_id,
                                                'block', NEW.val)
                           );

                WHEN 'blockStartOreRefine' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_ore_refine_start',
                            jsonb_build_object( 'struct_id', NEW.object_id,
                                                'block', NEW.val)
                           );
            END CASE;
        END IF;
        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER PLANET_ACTIVITY_STRUCT_ATTRIBUTE AFTER INSERT OR UPDATE OR DELETE ON structs.struct_attribute
        FOR EACH ROW EXECUTE PROCEDURE cache.PLANET_ACTIVITY_STRUCT_ATTRIBUTE();



    CREATE EXTENSION pg_cron;

    --SELECT cron.schedule('cleaner', '59 seconds', 'CALL cache.CLEAN_QUEUE();');

COMMIT;

