-- Deploy structs-pg:cache-trigger-add-queue-20260121-bigly-refactor to pg

BEGIN;

    DROP TABLE cache.event_handlers;
    CREATE TABLE IF NOT EXISTS cache.event_handlers (
        composite_key text PRIMARY KEY,
        handler regproc NOT NULL,
        description text,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
    );
    DROP TABLE cache.handler_error_log;
    CREATE TABLE IF NOT EXISTS cache.handler_error_log (
        id bigserial PRIMARY KEY,
        occurred_at timestamptz NOT NULL DEFAULT now(),
        composite_key text NOT NULL,
        handler regproc,
        payload jsonb,
        sqlstate text,
        message text,
        detail text,
        hint text,
        context text
    );

    CREATE OR REPLACE FUNCTION cache.handle_event_allocation(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x.type AS allocation_type,
            x."sourceObjectId" AS source_id,
            x."index" AS index,
            x."destinationId" AS destination_id,
            x.creator AS creator,
            x.controller AS controller,
            x.locked AS locked
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            type text,
            "sourceObjectId" text,
            "index" integer,
            "destinationId" text,
            creator text,
            controller text,
            locked boolean
        );

        INSERT INTO structs.allocation (
            id,
            allocation_type,
            source_id,
            index,
            destination_id,
            creator,
            controller,
            locked,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.allocation_type,
            v.source_id,
            v.index,
            v.destination_id,
            v.creator,
            v.controller,
            v.locked,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                destination_id = EXCLUDED.destination_id,
                controller = EXCLUDED.controller,
                locked = EXCLUDED.locked,
                updated_at = NOW()
            WHERE
                structs.allocation.destination_id IS DISTINCT FROM EXCLUDED.destination_id
                OR structs.allocation.controller IS DISTINCT FROM EXCLUDED.controller
                OR structs.allocation.locked IS DISTINCT FROM EXCLUDED.locked;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_agreement(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."providerId" AS provider_id,
            x."allocationId" AS allocation_id,
            x.capacity AS capacity,
            x."startBlock" AS start_block,
            x."endBlock" AS end_block,
            x.creator AS creator,
            x.owner AS owner
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "providerId" text,
            "allocationId" text,
            capacity bigint,
            "startBlock" bigint,
            "endBlock" bigint,
            creator text,
            owner text
        );

        INSERT INTO structs.agreement (
            id,
            provider_id,
            allocation_id,
            capacity,
            start_block,
            end_block,
            creator,
            owner,
            created_at,
            updated_at
        )
        VALUES (
           v.id,
           v.provider_id,
           v.allocation_id,
           v.capacity,
           v.start_block,
           v.end_block,
           v.creator,
           v.owner,
           NOW(),
           NOW()
         ) ON CONFLICT (id) DO UPDATE
            SET
                capacity=EXCLUDED.capacity,
                start_block=EXCLUDED.start_block,
                end_block=EXCLUDED.end_block,
                updated_at = NOW()
            WHERE
                structs.agreement.capacity IS DISTINCT FROM EXCLUDED.capacity
                OR structs.agreement.start_block IS DISTINCT FROM EXCLUDED.start_block
                OR structs.agreement.end_block IS DISTINCT FROM EXCLUDED.end_block;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_guild(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."index" AS index,
            x.endpoint AS endpoint,
            x."joinInfusionMinimum" AS join_infusion_minimum,
            x."joinInfusionMinimumBypassByRequest" AS join_infusion_minimum_bypass_by_request,
            x."joinInfusionMinimumBypassByInvite" AS join_infusion_minimum_bypass_by_invite,
            x."primaryReactorId" AS primary_reactor_id,
            x."entrySubstationId" AS entry_substation_id,
            x.creator AS creator,
            x.owner AS owner
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "index" integer,
            endpoint text,
            "joinInfusionMinimum" integer,
            "joinInfusionMinimumBypassByRequest" text,
            "joinInfusionMinimumBypassByInvite" text,
            "primaryReactorId" text,
            "entrySubstationId" text,
            creator text,
            owner text
        );

        INSERT INTO structs.guild (
            id,
            index,
            endpoint,
            join_infusion_minimum_p,
            join_infusion_minimum_bypass_by_request,
            join_infusion_minimum_bypass_by_invite,
            primary_reactor_id,
            entry_substation_id,
            creator,
            owner,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.index,
            v.endpoint,
            v.join_infusion_minimum,
            v.join_infusion_minimum_bypass_by_request,
            v.join_infusion_minimum_bypass_by_invite,
            v.primary_reactor_id,
            v.entry_substation_id,
            v.creator,
            v.owner,
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
                updated_at = NOW()
            WHERE
                structs.guild.endpoint IS DISTINCT FROM EXCLUDED.endpoint
                OR structs.guild.join_infusion_minimum_p IS DISTINCT FROM EXCLUDED.join_infusion_minimum_p
                OR structs.guild.join_infusion_minimum_bypass_by_request IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_request
                OR structs.guild.join_infusion_minimum_bypass_by_invite IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_invite
                OR structs.guild.primary_reactor_id IS DISTINCT FROM EXCLUDED.primary_reactor_id
                OR structs.guild.entry_substation_id IS DISTINCT FROM EXCLUDED.entry_substation_id
                OR structs.guild.owner IS DISTINCT FROM EXCLUDED.owner;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_infusion(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."destinationId" AS destination_id,
            x.address AS address,
            x."destinationType" AS destination_type,
            x."playerId" AS player_id,
            x.fuel AS fuel,
            x.defusing AS defusing,
            x.power AS power,
            x.ratio AS ratio,
            x.commission AS commission
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "destinationId" text,
            address text,
            "destinationType" text,
            "playerId" text,
            fuel numeric,
            defusing numeric,
            power numeric,
            ratio numeric,
            commission numeric
        );

        INSERT INTO structs.infusion (
            destination_id,
            address,
            destination_type,
            player_id,
            fuel_p,
            defusing_p,
            power_p,
            ratio_p,
            commission,
            created_at,
            updated_at
        )
        VALUES (
            v.destination_id,
            v.address,
            v.destination_type,
            v.player_id,
            v.fuel,
            v.defusing,
            v.power,
            v.ratio,
            v.commission,
            NOW(),
            NOW()
        ) ON CONFLICT (destination_id, address) DO UPDATE
            SET
                fuel_p = EXCLUDED.fuel_p,
                defusing_p = EXCLUDED.defusing_p,
                power_p = EXCLUDED.power_p,
                ratio_p = EXCLUDED.ratio_p,
                commission = EXCLUDED.commission,
                updated_at = NOW()
            WHERE
                structs.infusion.fuel_p IS DISTINCT FROM EXCLUDED.fuel_p
                OR structs.infusion.defusing_p IS DISTINCT FROM EXCLUDED.defusing_p
                OR structs.infusion.power_p IS DISTINCT FROM EXCLUDED.power_p
                OR structs.infusion.ratio_p IS DISTINCT FROM EXCLUDED.ratio_p
                OR structs.infusion.commission IS DISTINCT FROM EXCLUDED.commission;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_fleet(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x.owner AS owner,
            x.space AS space,
            x.air AS air,
            x.land AS land,
            x.water AS water,
            x."spaceSlots" AS space_slots,
            x."airSlots" AS air_slots,
            x."landSlots" AS land_slots,
            x."waterSlots" AS water_slots,
            x."locationType" AS location_type,
            x."locationId" AS location_id,
            x.status AS status,
            x."locationListForward" AS location_list_forward,
            x."locationListBackward" AS location_list_backward,
            x."commandStruct" AS command_struct
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            owner text,
            space jsonb,
            air jsonb,
            land jsonb,
            water jsonb,
            "spaceSlots" integer,
            "airSlots" integer,
            "landSlots" integer,
            "waterSlots" integer,
            "locationType" text,
            "locationId" text,
            status text,
            "locationListForward" text,
            "locationListBackward" text,
            "commandStruct" text
        );

        INSERT INTO structs.fleet (
            id,
            owner,
            map,
            space_slots,
            air_slots,
            land_slots,
            water_slots,
            location_type,
            location_id,
            status,
            location_list_forward,
            location_list_backward,
            command_struct,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.owner,
            jsonb_build_object('space', v.space) || jsonb_build_object('air', v.air) || jsonb_build_object('land', v.land) || jsonb_build_object('water', v.water),
            v.space_slots,
            v.air_slots,
            v.land_slots,
            v.water_slots,
            v.location_type,
            v.location_id,
            v.status,
            v.location_list_forward,
            v.location_list_backward,
            v.command_struct,
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

            updated_at = NOW()
        WHERE
            structs.fleet.owner IS DISTINCT FROM EXCLUDED.owner
            OR structs.fleet.map IS DISTINCT FROM EXCLUDED.map
            OR structs.fleet.location_type IS DISTINCT FROM EXCLUDED.location_type
            OR structs.fleet.location_id IS DISTINCT FROM EXCLUDED.location_id
            OR structs.fleet.status IS DISTINCT FROM EXCLUDED.status
            OR structs.fleet.location_list_forward IS DISTINCT FROM EXCLUDED.location_list_forward
            OR structs.fleet.location_list_backward IS DISTINCT FROM EXCLUDED.location_list_backward
            OR structs.fleet.command_struct IS DISTINCT FROM EXCLUDED.command_struct;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_planet(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."maxOre" AS max_ore,
            x.creator AS creator,
            x.owner AS owner,
            x.space AS space,
            x.air AS air,
            x.land AS land,
            x.water AS water,
            x."spaceSlots" AS space_slots,
            x."airSlots" AS air_slots,
            x."landSlots" AS land_slots,
            x."waterSlots" AS water_slots,
            x.status AS status,
            x."locationListStart" AS location_list_start,
            x."locationListEnd" AS location_list_end
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "maxOre" integer,
            creator text,
            owner text,
            space jsonb,
            air jsonb,
            land jsonb,
            water jsonb,
            "spaceSlots" integer,
            "airSlots" integer,
            "landSlots" integer,
            "waterSlots" integer,
            status text,
            "locationListStart" text,
            "locationListEnd" text
        );

        INSERT INTO structs.planet (
            id,
            max_ore,
            creator,
            owner,
            map,
            space_slots,
            air_slots,
            land_slots,
            water_slots,
            status,
            location_list_start,
            location_list_end,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.max_ore,
            v.creator,
            v.owner,
            jsonb_build_object('space', v.space) || jsonb_build_object('air', v.air) || jsonb_build_object('land', v.land) || jsonb_build_object('water', v.water),
            v.space_slots,
            v.air_slots,
            v.land_slots,
            v.water_slots,
            v.status,
            v.location_list_start,
            v.location_list_end,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,

                map = jsonb_build_object('space', EXCLUDED.map->'space') || jsonb_build_object('air', EXCLUDED.map->'air') || jsonb_build_object('land', EXCLUDED.map->'land') || jsonb_build_object('water', EXCLUDED.map->'water'),
                status = EXCLUDED.status,

                location_list_start = EXCLUDED.location_list_start,
                location_list_end = EXCLUDED.location_list_end,

                updated_at = NOW()
            WHERE
                structs.planet.owner IS DISTINCT FROM EXCLUDED.owner
                OR structs.planet.map IS DISTINCT FROM EXCLUDED.map
                OR structs.planet.status IS DISTINCT FROM EXCLUDED.status
                OR structs.planet.location_list_start IS DISTINCT FROM EXCLUDED.location_list_start
                OR structs.planet.location_list_end IS DISTINCT FROM EXCLUDED.location_list_end;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_player(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."index" AS index,
            x.creator AS creator,
            x."primaryAddress" AS primary_address,
            x."guildId" AS guild_id,
            x."substationId" AS substation_id,
            x."planetId" AS planet_id,
            x."fleetId" AS fleet_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "index" integer,
            creator text,
            "primaryAddress" text,
            "guildId" text,
            "substationId" text,
            "planetId" text,
            "fleetId" text
        );

        INSERT INTO structs.player (
            id,
            index,
            creator,
            primary_address,
            guild_id,
            substation_id,
            planet_id,
            fleet_id,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.index,
            v.creator,
            v.primary_address,
            v.guild_id,
            v.substation_id,
            v.planet_id,
            v.fleet_id,
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
                updated_at = NOW()
            WHERE
                structs.player.primary_address IS DISTINCT FROM EXCLUDED.primary_address
                OR structs.player.guild_id IS DISTINCT FROM EXCLUDED.guild_id
                OR structs.player.substation_id IS DISTINCT FROM EXCLUDED.substation_id
                OR structs.player.planet_id IS DISTINCT FROM EXCLUDED.planet_id
                OR structs.player.fleet_id IS DISTINCT FROM EXCLUDED.fleet_id;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.id)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_provider(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."index" AS index,
            x."substationId" AS substation_id,
            x.rate AS rate,
            x."accessPolicy" AS access_policy,
            x."capacityMinimum" AS capacity_minimum,
            x."capacityMaximum" AS capacity_maximum,
            x."durationMinimum" AS duration_minimum,
            x."durationMaximum" AS duration_maximum,
            x."providerCancellationPenalty" AS provider_cancellation_penalty,
            x."consumerCancellationPenalty" AS consumer_cancellation_penalty,
            x.creator AS creator,
            x.owner AS owner
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "index" integer,
            "substationId" text,
            rate jsonb,
            "accessPolicy" text,
            "capacityMinimum" numeric,
            "capacityMaximum" numeric,
            "durationMinimum" numeric,
            "durationMaximum" numeric,
            "providerCancellationPenalty" numeric,
            "consumerCancellationPenalty" numeric,
            creator text,
            owner text
        );

        INSERT INTO structs.provider (
            id,
            index,
            substation_id,
            rate_amount,
            rate_denom,
            access_policy,
            capacity_minimum,
            capacity_maximum,
            duration_minimum,
            duration_maximum,
            provider_cancellation_penalty,
            consumer_cancellation_penalty,
            creator,
            owner,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.index,
            v.substation_id,
            (v.rate->>'amount')::NUMERIC,
            v.rate->>'denom',
            v.access_policy,
            v.capacity_minimum,
            v.capacity_maximum,
            v.duration_minimum,
            v.duration_maximum,
            v.provider_cancellation_penalty,
            v.consumer_cancellation_penalty,
            v.creator,
            v.owner,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                access_policy=EXCLUDED.access_policy,
                capacity_minimum=EXCLUDED.capacity_minimum,
                capacity_maximum=EXCLUDED.capacity_maximum,
                duration_minimum=EXCLUDED.duration_minimum,
                duration_maximum=EXCLUDED.duration_maximum,
                updated_at = NOW()
            WHERE
                structs.provider.access_policy IS DISTINCT FROM EXCLUDED.access_policy
                OR structs.provider.capacity_minimum IS DISTINCT FROM EXCLUDED.capacity_minimum
                OR structs.provider.capacity_maximum IS DISTINCT FROM EXCLUDED.capacity_maximum
                OR structs.provider.duration_minimum IS DISTINCT FROM EXCLUDED.duration_minimum
                OR structs.provider.duration_maximum IS DISTINCT FROM EXCLUDED.duration_maximum;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_reactor(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x.validator AS validator,
            x."guildId" AS guild_id,
            x."defaultCommission" AS default_commission
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            validator text,
            "guildId" text,
            "defaultCommission" numeric
        );

        INSERT INTO structs.reactor (
            id,
            validator,
            guild_id,
            default_commission,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.validator,
            v.guild_id,
            v.default_commission,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                guild_id = EXCLUDED.guild_id,
                default_commission = EXCLUDED.default_commission,
                updated_at = NOW()
            WHERE
                structs.reactor.guild_id IS DISTINCT FROM EXCLUDED.guild_id
                OR structs.reactor.default_commission IS DISTINCT FROM EXCLUDED.default_commission;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_struct(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x."index" AS index,
            x.type AS type,
            x.creator AS creator,
            x.owner AS owner,
            x."locationType" AS location_type,
            x."locationId" AS location_id,
            x."operatingAmbit" AS operating_ambit,
            x.slot AS slot
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "index" integer,
            type integer,
            creator text,
            owner text,
            "locationType" text,
            "locationId" text,
            "operatingAmbit" text,
            slot integer
        );

        INSERT INTO structs.struct (
            id,
            index,
            type,
            creator,
            owner,
            location_type,
            location_id,
            operating_ambit,
            slot,
            created_at,
            updated_at,
            is_destroyed
        )
        VALUES (
            v.id,
            v.index,
            v.type,
            v.creator,
            v.owner,
            v.location_type,
            v.location_id,
            v.operating_ambit,
            v.slot,
            NOW(),
            NOW(),
            'f'
        ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,
                location_type = EXCLUDED.location_type,
                location_id = EXCLUDED.location_id,
                operating_ambit = EXCLUDED.operating_ambit,
                slot = EXCLUDED.slot,
                updated_at = NOW()
            WHERE
                structs.struct.owner IS DISTINCT FROM EXCLUDED.owner
                OR structs.struct.location_type IS DISTINCT FROM EXCLUDED.location_type
                OR structs.struct.location_id IS DISTINCT FROM EXCLUDED.location_id
                OR structs.struct.operating_ambit IS DISTINCT FROM EXCLUDED.operating_ambit
                OR structs.struct.slot IS DISTINCT FROM EXCLUDED.slot;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_struct_defender(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."defendingStructId" AS defending_struct_id,
            x."protectedStructId" AS protected_struct_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "defendingStructId" text,
            "protectedStructId" text
        );

        INSERT INTO structs.struct_defender (
            defending_struct_id,
            protected_struct_id,
            updated_at
        )
        VALUES (
            v.defending_struct_id,
            v.protected_struct_id,
            NOW()
        ) ON CONFLICT (defending_struct_id) DO UPDATE
        SET
            defending_struct_id = EXCLUDED.defending_struct_id,
            protected_struct_id = EXCLUDED.protected_struct_id,
            updated_at = EXCLUDED.updated_at
        WHERE
            structs.struct_defender.protected_struct_id IS DISTINCT FROM EXCLUDED.protected_struct_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_struct_defender_clear(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."defendingStructId" AS defending_struct_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "defendingStructId" text
        );

        DELETE FROM structs.struct_defender WHERE defending_struct_id = v.defending_struct_id;
        DELETE FROM structs.struct_attribute WHERE id = '5-' || v.defending_struct_id::CHARACTER VARYING;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_struct_type(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id AS id,
            x.type AS type,
            x.category AS category,
            x."buildLimit" AS build_limit,
            x."buildDifficulty" AS build_difficulty,
            x."buildDraw" AS build_draw,
            x."maxHealth" AS max_health,
            x."passiveDraw" AS passive_draw,
            x."possibleAmbit" AS possible_ambit,
            x.movable AS movable,
            x."slotBound" AS slot_bound,
            x."primaryWeapon" AS primary_weapon,
            x."primaryWeaponControl" AS primary_weapon_control,
            x."primaryWeaponCharge" AS primary_weapon_charge,
            x."primaryWeaponAmbits" AS primary_weapon_ambits,
            x."primaryWeaponTargets" AS primary_weapon_targets,
            x."primaryWeaponShots" AS primary_weapon_shots,
            x."primaryWeaponDamage" AS primary_weapon_damage,
            x."primaryWeaponBlockable" AS primary_weapon_blockable,
            x."primaryWeaponCounterable" AS primary_weapon_counterable,
            x."primaryWeaponRecoilDamage" AS primary_weapon_recoil_damage,
            x."primaryWeaponShotSuccessRateNumerator" AS primary_weapon_shot_success_rate_numerator,
            x."primaryWeaponShotSuccessRateDenominator" AS primary_weapon_shot_success_rate_denominator,
            x."secondaryWeapon" AS secondary_weapon,
            x."secondaryWeaponControl" AS secondary_weapon_control,
            x."secondaryWeaponCharge" AS secondary_weapon_charge,
            x."secondaryWeaponAmbits" AS secondary_weapon_ambits,
            x."secondaryWeaponTargets" AS secondary_weapon_targets,
            x."secondaryWeaponShots" AS secondary_weapon_shots,
            x."secondaryWeaponDamage" AS secondary_weapon_damage,
            x."secondaryWeaponBlockable" AS secondary_weapon_blockable,
            x."secondaryWeaponCounterable" AS secondary_weapon_counterable,
            x."secondaryWeaponRecoilDamage" AS secondary_weapon_recoil_damage,
            x."secondaryWeaponShotSuccessRateNumerator" AS secondary_weapon_shot_success_rate_numerator,
            x."secondaryWeaponShotSuccessRateDenominator" AS secondary_weapon_shot_success_rate_denominator,
            x."passiveWeaponry" AS passive_weaponry,
            x."unitDefenses" AS unit_defenses,
            x."oreReserveDefenses" AS ore_reserve_defenses,
            x."planetaryDefenses" AS planetary_defenses,
            x."planetaryMining" AS planetary_mining,
            x."planetaryRefinery" AS planetary_refinery,
            x."powerGeneration" AS power_generation,
            x."activateCharge" AS activate_charge,
            x."buildCharge" AS build_charge,
            x."defendChangeCharge" AS defend_change_charge,
            x."moveCharge" AS move_charge,
            x."stealthActivateCharge" AS stealth_activate_charge,
            x."attackReduction" AS attack_reduction,
            x."attackCounterable" AS attack_counterable,
            x."stealthSystems" AS stealth_systems,
            x."counterAttack" AS counter_attack,
            x."counterAttackSameAmbit" AS counter_attack_same_ambit,
            x."postDestructionDamage" AS post_destruction_damage,
            x."generatingRate" AS generating_rate,
            x."planetaryShieldContribution" AS planetary_shield_contribution,
            x."oreMiningDifficulty" AS ore_mining_difficulty,
            x."oreRefiningDifficulty" AS ore_refining_difficulty,
            x."unguidedDefensiveSuccessRateNumerator" AS unguided_defensive_success_rate_numerator,
            x."unguidedDefensiveSuccessRateDenominator" AS unguided_defensive_success_rate_denominator,
            x."guidedDefensiveSuccessRateNumerator" AS guided_defensive_success_rate_numerator,
            x."guidedDefensiveSuccessRateDenominator" AS guided_defensive_success_rate_denominator,
            x."triggerRaidDefeatByDestruction" AS trigger_raid_defeat_by_destruction,
            x.class AS class,
            x."classAbbreviation" AS class_abbreviation,
            x."defaultCosmeticModelNumber" AS default_cosmetic_model_number,
            x."defaultCosmeticName" AS default_cosmetic_name
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id integer,
            type text,
            category text,
            "buildLimit" integer,
            "buildDifficulty" integer,
            "buildDraw" integer,
            "maxHealth" integer,
            "passiveDraw" integer,
            "possibleAmbit" integer,
            movable boolean,
            "slotBound" boolean,
            "primaryWeapon" text,
            "primaryWeaponControl" text,
            "primaryWeaponCharge" integer,
            "primaryWeaponAmbits" integer,
            "primaryWeaponTargets" integer,
            "primaryWeaponShots" integer,
            "primaryWeaponDamage" integer,
            "primaryWeaponBlockable" boolean,
            "primaryWeaponCounterable" boolean,
            "primaryWeaponRecoilDamage" integer,
            "primaryWeaponShotSuccessRateNumerator" integer,
            "primaryWeaponShotSuccessRateDenominator" integer,
            "secondaryWeapon" text,
            "secondaryWeaponControl" text,
            "secondaryWeaponCharge" integer,
            "secondaryWeaponAmbits" integer,
            "secondaryWeaponTargets" integer,
            "secondaryWeaponShots" integer,
            "secondaryWeaponDamage" integer,
            "secondaryWeaponBlockable" boolean,
            "secondaryWeaponCounterable" boolean,
            "secondaryWeaponRecoilDamage" integer,
            "secondaryWeaponShotSuccessRateNumerator" integer,
            "secondaryWeaponShotSuccessRateDenominator" integer,
            "passiveWeaponry" text,
            "unitDefenses" text,
            "oreReserveDefenses" text,
            "planetaryDefenses" text,
            "planetaryMining" text,
            "planetaryRefinery" text,
            "powerGeneration" text,
            "activateCharge" integer,
            "buildCharge" integer,
            "defendChangeCharge" integer,
            "moveCharge" integer,
            "stealthActivateCharge" integer,
            "attackReduction" integer,
            "attackCounterable" boolean,
            "stealthSystems" boolean,
            "counterAttack" integer,
            "counterAttackSameAmbit" integer,
            "postDestructionDamage" integer,
            "generatingRate" integer,
            "planetaryShieldContribution" integer,
            "oreMiningDifficulty" integer,
            "oreRefiningDifficulty" integer,
            "unguidedDefensiveSuccessRateNumerator" integer,
            "unguidedDefensiveSuccessRateDenominator" integer,
            "guidedDefensiveSuccessRateNumerator" integer,
            "guidedDefensiveSuccessRateDenominator" integer,
            "triggerRaidDefeatByDestruction" boolean,
            class text,
            "classAbbreviation" text,
            "defaultCosmeticModelNumber" text,
            "defaultCosmeticName" text
        );

        INSERT INTO structs.struct_type(
            id,
            type,
            category,
            build_limit ,
            build_difficulty,
            build_draw_p,
            max_health,
            passive_draw_p,
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
            class,
            class_abbreviation,
            default_cosmetic_model_number,
            default_cosmetic_name,
            is_command
        )
        VALUES (
                       v.id,
                       v.type,

                       v.category,

                       v.build_limit,
                       v.build_difficulty,
                       v.build_draw,
                       v.max_health,
                       v.passive_draw,
                       v.possible_ambit,

                       v.movable,
                       v.slot_bound,


                       v.primary_weapon,
                       v.primary_weapon_control,
                       v.primary_weapon_charge,
                       v.primary_weapon_ambits,
                       v.primary_weapon_targets,
                       v.primary_weapon_shots,
                       v.primary_weapon_damage,
                       v.primary_weapon_blockable,
                       v.primary_weapon_counterable,
                       v.primary_weapon_recoil_damage,
                       v.primary_weapon_shot_success_rate_numerator,
                       v.primary_weapon_shot_success_rate_denominator,

                       v.secondary_weapon,
                       v.secondary_weapon_control,
                       v.secondary_weapon_charge,
                       v.secondary_weapon_ambits,
                       v.secondary_weapon_targets,
                       v.secondary_weapon_shots,
                       v.secondary_weapon_damage,
                       v.secondary_weapon_blockable,
                       v.secondary_weapon_counterable,
                       v.secondary_weapon_recoil_damage,
                       v.secondary_weapon_shot_success_rate_numerator,
                       v.secondary_weapon_shot_success_rate_denominator,


                       v.passive_weaponry,
                       v.unit_defenses,
                       v.ore_reserve_defenses,
                       v.planetary_defenses,
                       v.planetary_mining,
                       v.planetary_refinery,
                       v.power_generation,

                       v.activate_charge,
                       v.build_charge,
                       v.defend_change_charge,
                       v.move_charge,
                       v.stealth_activate_charge,

                       v.attack_reduction,
                       v.attack_counterable,
                       v.stealth_systems,
                       v.counter_attack,
                       v.counter_attack_same_ambit,
                       v.post_destruction_damage,
                       v.generating_rate,
                       v.planetary_shield_contribution,
                       v.ore_mining_difficulty,
                       v.ore_refining_difficulty,

                       v.unguided_defensive_success_rate_numerator,
                       v.unguided_defensive_success_rate_denominator,

                       v.guided_defensive_success_rate_numerator,
                       v.guided_defensive_success_rate_denominator,

                       v.trigger_raid_defeat_by_destruction,

                       NOW(),
                       v.class,
                       v.class_abbreviation,
                       v.default_cosmetic_model_number,
                       v.default_cosmetic_name,
                       (v.class = 'Command Ship')
               ) ON CONFLICT (id) DO UPDATE
        SET
            type = EXCLUDED.type,
            category = EXCLUDED.category,
            build_limit = EXCLUDED.build_limit,
            build_difficulty = EXCLUDED.build_difficulty,
            build_draw_p = EXCLUDED.build_draw_p,
            max_health = EXCLUDED.max_health,
            passive_draw_p = EXCLUDED.passive_draw_p,
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
            default_cosmetic_name= EXCLUDED.default_cosmetic_name,
            is_command = EXCLUDED.is_command
        WHERE
            (
                structs.struct_type.type,
                structs.struct_type.category,
                structs.struct_type.build_limit,
                structs.struct_type.build_difficulty,
                structs.struct_type.build_draw_p,
                structs.struct_type.max_health,
                structs.struct_type.passive_draw_p,
                structs.struct_type.possible_ambit,
                structs.struct_type.movable,
                structs.struct_type.slot_bound,
                structs.struct_type.primary_weapon,
                structs.struct_type.primary_weapon_control,
                structs.struct_type.primary_weapon_charge,
                structs.struct_type.primary_weapon_ambits,
                structs.struct_type.primary_weapon_targets,
                structs.struct_type.primary_weapon_shots,
                structs.struct_type.primary_weapon_damage,
                structs.struct_type.primary_weapon_blockable,
                structs.struct_type.primary_weapon_counterable,
                structs.struct_type.primary_weapon_recoil_damage,
                structs.struct_type.primary_weapon_shot_success_rate_numerator,
                structs.struct_type.primary_weapon_shot_success_rate_denominator,
                structs.struct_type.secondary_weapon,
                structs.struct_type.secondary_weapon_control,
                structs.struct_type.secondary_weapon_charge,
                structs.struct_type.secondary_weapon_ambits,
                structs.struct_type.secondary_weapon_targets,
                structs.struct_type.secondary_weapon_shots,
                structs.struct_type.secondary_weapon_damage,
                structs.struct_type.secondary_weapon_blockable,
                structs.struct_type.secondary_weapon_counterable,
                structs.struct_type.secondary_weapon_recoil_damage,
                structs.struct_type.secondary_weapon_shot_success_rate_numerator,
                structs.struct_type.secondary_weapon_shot_success_rate_denominator,
                structs.struct_type.passive_weaponry,
                structs.struct_type.unit_defenses,
                structs.struct_type.ore_reserve_defenses,
                structs.struct_type.planetary_defenses,
                structs.struct_type.planetary_mining,
                structs.struct_type.planetary_refinery,
                structs.struct_type.power_generation,
                structs.struct_type.activate_charge,
                structs.struct_type.build_charge,
                structs.struct_type.defend_change_charge,
                structs.struct_type.move_charge,
                structs.struct_type.stealth_activate_charge,
                structs.struct_type.attack_reduction,
                structs.struct_type.attack_counterable,
                structs.struct_type.stealth_systems,
                structs.struct_type.counter_attack,
                structs.struct_type.counter_attack_same_ambit,
                structs.struct_type.post_destruction_damage,
                structs.struct_type.generating_rate,
                structs.struct_type.planetary_shield_contribution,
                structs.struct_type.ore_mining_difficulty,
                structs.struct_type.ore_refining_difficulty,
                structs.struct_type.unguided_defensive_success_rate_numerator,
                structs.struct_type.unguided_defensive_success_rate_denominator,
                structs.struct_type.guided_defensive_success_rate_numerator,
                structs.struct_type.guided_defensive_success_rate_denominator,
                structs.struct_type.trigger_raid_defeat_by_destruction,
                structs.struct_type.class,
                structs.struct_type.class_abbreviation,
                structs.struct_type.default_cosmetic_model_number,
                structs.struct_type.default_cosmetic_name,
                structs.struct_type.is_command
            ) IS DISTINCT FROM (
                EXCLUDED.type,
                EXCLUDED.category,
                EXCLUDED.build_limit,
                EXCLUDED.build_difficulty,
                EXCLUDED.build_draw_p,
                EXCLUDED.max_health,
                EXCLUDED.passive_draw_p,
                EXCLUDED.possible_ambit,
                EXCLUDED.movable,
                EXCLUDED.slot_bound,
                EXCLUDED.primary_weapon,
                EXCLUDED.primary_weapon_control,
                EXCLUDED.primary_weapon_charge,
                EXCLUDED.primary_weapon_ambits,
                EXCLUDED.primary_weapon_targets,
                EXCLUDED.primary_weapon_shots,
                EXCLUDED.primary_weapon_damage,
                EXCLUDED.primary_weapon_blockable,
                EXCLUDED.primary_weapon_counterable,
                EXCLUDED.primary_weapon_recoil_damage,
                EXCLUDED.primary_weapon_shot_success_rate_numerator,
                EXCLUDED.primary_weapon_shot_success_rate_denominator,
                EXCLUDED.secondary_weapon,
                EXCLUDED.secondary_weapon_control,
                EXCLUDED.secondary_weapon_charge,
                EXCLUDED.secondary_weapon_ambits,
                EXCLUDED.secondary_weapon_targets,
                EXCLUDED.secondary_weapon_shots,
                EXCLUDED.secondary_weapon_damage,
                EXCLUDED.secondary_weapon_blockable,
                EXCLUDED.secondary_weapon_counterable,
                EXCLUDED.secondary_weapon_recoil_damage,
                EXCLUDED.secondary_weapon_shot_success_rate_numerator,
                EXCLUDED.secondary_weapon_shot_success_rate_denominator,
                EXCLUDED.passive_weaponry,
                EXCLUDED.unit_defenses,
                EXCLUDED.ore_reserve_defenses,
                EXCLUDED.planetary_defenses,
                EXCLUDED.planetary_mining,
                EXCLUDED.planetary_refinery,
                EXCLUDED.power_generation,
                EXCLUDED.activate_charge,
                EXCLUDED.build_charge,
                EXCLUDED.defend_change_charge,
                EXCLUDED.move_charge,
                EXCLUDED.stealth_activate_charge,
                EXCLUDED.attack_reduction,
                EXCLUDED.attack_counterable,
                EXCLUDED.stealth_systems,
                EXCLUDED.counter_attack,
                EXCLUDED.counter_attack_same_ambit,
                EXCLUDED.post_destruction_damage,
                EXCLUDED.generating_rate,
                EXCLUDED.planetary_shield_contribution,
                EXCLUDED.ore_mining_difficulty,
                EXCLUDED.ore_refining_difficulty,
                EXCLUDED.unguided_defensive_success_rate_numerator,
                EXCLUDED.unguided_defensive_success_rate_denominator,
                EXCLUDED.guided_defensive_success_rate_numerator,
                EXCLUDED.guided_defensive_success_rate_denominator,
                EXCLUDED.trigger_raid_defeat_by_destruction,
                EXCLUDED.class,
                EXCLUDED.class_abbreviation,
                EXCLUDED.default_cosmetic_model_number,
                EXCLUDED.default_cosmetic_name,
                EXCLUDED.is_command
            );
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_substation(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT *
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            owner text,
            creator text
        );

        INSERT INTO structs.substation (
            id,
            owner,
            creator,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.owner,
            v.creator,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                owner = EXCLUDED.owner,
                updated_at = NOW()
            WHERE
                structs.substation.owner IS DISTINCT FROM EXCLUDED.owner;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_guild_membership_application(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."guildId" AS guild_id,
            x."playerId" AS player_id,
            x."joinType" AS join_type,
            x."registrationStatus" AS registration_status,
            x.proposer AS proposer,
            x."substationId" AS substation_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "guildId" text,
            "playerId" text,
            "joinType" text,
            "registrationStatus" text,
            proposer text,
            "substationId" text
        );

        INSERT INTO structs.guild_membership_application (
            guild_id,
            player_id,
            join_type,
            status,
            proposer,
            substation_id,
            created_at,
            updated_at
        )
        VALUES (
            v.guild_id,
            v.player_id,
            v.join_type,
            v.registration_status,
            v.proposer,
            v.substation_id,
            NOW(),
            NOW()
       ) ON CONFLICT (guild_id, player_id) DO UPDATE
        SET
            join_type = EXCLUDED.join_type,
            status = EXCLUDED.status,
            proposer = EXCLUDED.proposer,
            substation_id = EXCLUDED.substation_id,
            updated_at = NOW()
        WHERE
            structs.guild_membership_application.join_type IS DISTINCT FROM EXCLUDED.join_type
            OR structs.guild_membership_application.status IS DISTINCT FROM EXCLUDED.status
            OR structs.guild_membership_application.proposer IS DISTINCT FROM EXCLUDED.proposer
            OR structs.guild_membership_application.substation_id IS DISTINCT FROM EXCLUDED.substation_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_address_activity(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.address AS address,
            x."blockHeight" AS block_height,
            x."blockTime" AS block_time
        INTO v
        FROM jsonb_to_record(payload) AS x(
            address text,
            "blockHeight" bigint,
            "blockTime" timestamptz
        );

        INSERT INTO structs.player_address_activity (
            address,
            player_id,
            block_height,
            block_time
        )
        VALUES (
            v.address,
            (select player_address.player_id from structs.player_address where player_address.address = v.address),
            v.block_height,
            v.block_time
        ) ON CONFLICT (address) DO UPDATE
        SET
            block_height = EXCLUDED.block_height,
            block_time = EXCLUDED.block_time
        WHERE
            structs.player_address_activity.block_height IS DISTINCT FROM EXCLUDED.block_height
            OR structs.player_address_activity.block_time IS DISTINCT FROM EXCLUDED.block_time;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_address(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.address AS address,
            x."playerId" AS player_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            address text,
            "playerId" text
        );

        INSERT INTO structs.player_address (
            address,
            player_id,
            guild_id,
            status,
            created_at,
            updated_at
        )
        VALUES (
            v.address,
            v.player_id,
            (select guild_id from structs.player where player.id = v.player_id),
            'approved',
            NOW(),
            NOW()
        ) ON CONFLICT (address) DO UPDATE
        SET
            status = EXCLUDED.status,
            player_id = EXCLUDED.player_id,
            updated_at = EXCLUDED.updated_at
        WHERE
            structs.player_address.status IS DISTINCT FROM EXCLUDED.status
            OR structs.player_address.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_address_association(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.address AS address,
            x."playerIndex" AS player_index,
            x."registrationStatus" AS registration_status
        INTO v
        FROM jsonb_to_record(payload) AS x(
            address text,
            "playerIndex" integer,
            "registrationStatus" text
        );

        INSERT INTO structs.player_address (
            address,
            player_id,
            guild_id,
            status,
            created_at,
            updated_at
        )
        VALUES (
            v.address,
            '1-' || v.player_index::CHARACTER VARYING,
            (select guild_id from structs.player where player.id=('1-' || v.player_index::CHARACTER VARYING)),
            v.registration_status,
            NOW(),
            NOW()
        ) ON CONFLICT (address) DO UPDATE
        SET
            status = EXCLUDED.status,
            player_id = EXCLUDED.player_id,
            updated_at = EXCLUDED.updated_at
        WHERE
            structs.player_address.status IS DISTINCT FROM EXCLUDED.status
            OR structs.player_address.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_permission(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."permissionId" AS permission_id,
            x.value AS value
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "permissionId" text,
            value text
        );

        IF v.value = '' THEN
            DELETE FROM structs.permission WHERE id = v.permission_id;
        ELSE

            INSERT INTO structs.permission
            VALUES (
                v.permission_id,
                CASE split_part(v.permission_id,'-',1)
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
                split_part(split_part(v.permission_id,'-',2),'@',1),

                CASE split_part(v.permission_id,'-',1)
                    WHEN '8' THEN (SELECT player_address.player_id FROM structs.player_address WHERE player_address.address = split_part(split_part(v.permission_id,'-',2),'@',1))
                    ELSE split_part(v.permission_id,'@',1)
                END,

                CASE split_part(v.permission_id,'-',1)
                    WHEN '8' THEN (SELECT player_address.player_id FROM structs.player_address WHERE player_address.address = split_part(split_part(v.permission_id,'-',2),'@',1))
                    ELSE split_part(v.permission_id,'@',2)
                END,

                (v.value)::INTEGER,
                NOW()
            ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at
            WHERE
                structs.permission.val IS DISTINCT FROM EXCLUDED.val;
        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_grid(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
        grid_rowcount integer;
    BEGIN
        SELECT
            x."attributeId" AS attribute_id,
            x.value AS value
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "attributeId" text,
            value text
        );

        IF v.value = '' THEN
            DELETE FROM structs.grid WHERE id = v.attribute_id;
            GET DIAGNOSTICS grid_rowcount = ROW_COUNT;

            IF grid_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                    WHEN '0' THEN
                        INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '1' THEN
                        INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '2' THEN
                        INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '3' THEN
                        INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '4' THEN
                        INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '5' THEN
                        INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '6' THEN
                        INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '7' THEN
                        INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    ELSE

                END CASE;
            END IF;
        ELSE

            INSERT INTO structs.grid
            VALUES (
                v.attribute_id,

                CASE split_part(v.attribute_id, '-',1)
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

                CASE split_part(v.attribute_id, '-', 2)
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

                (split_part(v.attribute_id, '-', 3))::INTEGER,
                split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3),

                (v.value)::INTEGER,
                NOW()
                ) ON CONFLICT (id) DO UPDATE
                      SET
                          val = EXCLUDED.val,
                      updated_at = EXCLUDED.updated_at
                WHERE
                    structs.grid.val IS DISTINCT FROM EXCLUDED.val;

            GET DIAGNOSTICS grid_rowcount = ROW_COUNT;
            IF grid_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                                WHEN '0' THEN
                                 INSERT INTO structs.stat_ore VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '1' THEN
                                 INSERT INTO structs.stat_fuel VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '2' THEN
                                 INSERT INTO structs.stat_capacity VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '3' THEN
                                 INSERT INTO structs.stat_load VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '4' THEN
                                 INSERT INTO structs.stat_structs_load VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '5' THEN
                                 INSERT INTO structs.stat_power VALUES (NOW(), structs.GET_OBJECT_TYPE((split_part(v.attribute_id, '-', 2))::INTEGER), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '6' THEN
                                 INSERT INTO structs.stat_connection_capacity VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                WHEN '7' THEN
                                 INSERT INTO structs.stat_connection_count VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                ELSE

                END CASE;
            END IF;

        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_struct_attribute(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
        struct_attr_rowcount integer;
    BEGIN
        SELECT
            x."attributeId" AS attribute_id,
            x.value AS value
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "attributeId" text,
            value text
        );

        IF v.value = '' THEN
            DELETE FROM structs.struct_attribute WHERE id = v.attribute_id;
            GET DIAGNOSTICS struct_attr_rowcount = ROW_COUNT;

            IF struct_attr_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                    WHEN '0' THEN
                      INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    WHEN '1' THEN
                       INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, 0);
                    ELSE
                END CASE;
            END IF;
        ELSE

            INSERT INTO structs.struct_attribute
            VALUES (
                       v.attribute_id,

                       split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3),
                       CASE split_part(v.attribute_id, '-', 2)
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
                       CASE split_part(v.attribute_id, '-', 4) WHEN '' THEN 0 ELSE (split_part(v.attribute_id, '-', 4))::INTEGER END,

                       CASE split_part(v.attribute_id, '-', 1)
                           WHEN '0' THEN 'health'
                           WHEN '1' THEN 'status'
                           WHEN '2' THEN 'blockStartBuild'
                           WHEN '3' THEN 'blockStartOreMine'
                           WHEN '4' THEN 'blockStartOreRefine'
                           WHEN '5' THEN 'protectedStructIndex'
                           WHEN '6' THEN 'typeCount'
                       END,
                       (v.value)::INTEGER,
                       NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at
            WHERE
                structs.struct_attribute.val IS DISTINCT FROM EXCLUDED.val;

            GET DIAGNOSTICS struct_attr_rowcount = ROW_COUNT;
            IF struct_attr_rowcount > 0 THEN
                CASE split_part(v.attribute_id, '-',1)
                    WHEN '0' THEN
                       INSERT INTO structs.stat_struct_health VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                    WHEN '1' THEN
                       INSERT INTO structs.stat_struct_status VALUES (NOW(), (split_part(v.attribute_id, '-', 3))::INTEGER, (v.value)::INTEGER);
                       IF ((v.value)::INTEGER & 32) > 0 THEN
                           UPDATE structs.struct SET is_destroyed = 't' WHERE id = split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3);
                       END IF;
                    ELSE
                END CASE;
            END IF;

        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_planet_attribute(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."attributeId" AS attribute_id,
            x.value AS value
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "attributeId" text,
            value text
        );

        IF v.value = '' THEN
            DELETE FROM structs.planet_attribute WHERE id = v.attribute_id;
        ELSE

            INSERT INTO structs.planet_attribute
                VALUES (
                    v.attribute_id,
                    split_part(v.attribute_id, '-', 2) || '-' || split_part(v.attribute_id, '-', 3),
                    CASE split_part(v.attribute_id, '-', 2)
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

                    CASE split_part(v.attribute_id, '-', 1)
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
                    (v.value)::INTEGER,
                    NOW()
                   ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at
            WHERE
                structs.planet_attribute.val IS DISTINCT FROM EXCLUDED.val;
        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_attack(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."attackerStructId" AS attacker_struct_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "attackerStructId" text
        );

        WITH r_location AS (
            SELECT structs.GET_ACTIVITY_LOCATION_ID(v.attacker_struct_id) as location_id
        )
        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
            SELECT
                    NOW(),
                    structs.GET_PLANET_ACTIVITY_SEQUENCE(r_location.location_id),
                    r_location.location_id,
                    'struct_attack',
                    payload
                FROM r_location;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_ore_mine(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."primaryAddress" AS primary_address,
            x.amount AS amount
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "primaryAddress" text,
            amount numeric
        );

        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
            VALUES( v.primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'mined', 'credit', 'ore');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_ore_migrate(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."primaryAddress" AS primary_address,
            x."oldPrimaryAddress" AS old_primary_address,
            x.amount AS amount
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "primaryAddress" text,
            "oldPrimaryAddress" text,
            amount numeric
        );

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
            VALUES( v.primary_address, v.old_primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1),NOW(), 'migrated', 'credit', 'ore');

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
            VALUES( v.old_primary_address, v.primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'migrated', 'debit', 'ore');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_ore_theft(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."thiefPrimaryAddress" AS thief_primary_address,
            x."victimPrimaryAddress" AS victim_primary_address,
            x.amount AS amount
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "thiefPrimaryAddress" text,
            "victimPrimaryAddress" text,
            amount numeric
        );

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
            VALUES( v.thief_primary_address, v.victim_primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'seized', 'credit', 'ore');

        INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom)
            VALUES( v.victim_primary_address, v.thief_primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'forfeited', 'debit', 'ore');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_alpha_refine(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."primaryAddress" AS primary_address,
            x.amount AS amount
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "primaryAddress" text,
            amount numeric
        );

        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
            VALUES( v.primary_address, v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'debit', 'ore');

        INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom)
            VALUES( v.primary_address, 1000000 * v.amount, (SELECT current_block.height FROM structs.current_block LIMIT 1), NOW(), 'refined', 'credit', 'ualpha');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_raid(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."fleetId" AS fleet_id,
            x."planetId" AS planet_id,
            x.status AS status
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "fleetId" text,
            "planetId" text,
            status text
        );

        INSERT INTO structs.planet_raid (fleet_id, planet_id, status, updated_at)
        VALUES (
            v.fleet_id,
            v.planet_id,
            v.status,
            NOW()
        ) ON CONFLICT (planet_id) DO UPDATE
            SET
                fleet_id = EXCLUDED.fleet_id,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at
            WHERE
                structs.planet_raid.fleet_id IS DISTINCT FROM EXCLUDED.fleet_id
                OR structs.planet_raid.status IS DISTINCT FROM EXCLUDED.status;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_time(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."blockHeight" AS block_height,
            x."blockTime" AS block_time
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "blockHeight" bigint,
            "blockTime" timestamptz
        );

        INSERT INTO structs.current_block (chain, height, updated_at)
            VALUES ('testnet', v.block_height, v.block_time)
            ON CONFLICT (chain) DO UPDATE
            SET height = EXCLUDED.height, updated_at = EXCLUDED.updated_at
            WHERE structs.current_block.height IS DISTINCT FROM EXCLUDED.height
                OR structs.current_block.updated_at IS DISTINCT FROM EXCLUDED.updated_at;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_provider_address(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."collateralPool" AS collateral_pool,
            x."providerId" AS provider_id,
            x."earningPool" AS earning_pool
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "collateralPool" text,
            "providerId" text,
            "earningPool" text
        );

        INSERT INTO structs.address_tag (address, label, entry, updated_at, created_at)
        VALUES (
            v.collateral_pool,
            'Type',
            'Provider Collateral Pool',
            NOW(),
            NOW()
        ),
        (
            v.collateral_pool,
            'ProviderId',
            v.provider_id,
            NOW(),
            NOW()
        ),
        (
            v.earning_pool,
            'Type',
            'Provider Earning Pool',
            NOW(),
            NOW()
        ),
        (
            v.earning_pool,
            'ProviderId',
            v.provider_id,
            NOW(),
            NOW()
        )
        ON CONFLICT (address, label) DO UPDATE
        SET
            entry = EXCLUDED.entry,
            updated_at = EXCLUDED.updated_at
        WHERE
            structs.address_tag.entry IS DISTINCT FROM EXCLUDED.entry;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_guild_bank_address(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."bankCollateralPool" AS bank_collateral_pool,
            x."guildId" AS guild_id
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "bankCollateralPool" text,
            "guildId" text
        );

        INSERT INTO structs.address_tag (address, label, entry, updated_at, created_at)
        VALUES (
            v.bank_collateral_pool,
            'Type',
            'Bank Collateral Pool',
            NOW(),
            NOW()
        ),
        (
            v.bank_collateral_pool,
            'GuildId',
            v.guild_id,
            NOW(),
            NOW()
        )
        ON CONFLICT (address, label) DO UPDATE
        SET
            entry = EXCLUDED.entry,
            updated_at = EXCLUDED.updated_at
        WHERE
            structs.address_tag.entry IS DISTINCT FROM EXCLUDED.entry;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.ADD_QUEUE()
    RETURNS trigger AS
    $BODY$
    DECLARE
        handler regproc;
        err_sqlstate text;
        message text;
        detail text;
        hint text;
        context text;
    BEGIN
        SELECT h.handler INTO handler
        FROM cache.event_handlers h
        WHERE h.composite_key = NEW.composite_key;

        IF handler IS NOT NULL THEN
            BEGIN
                EXECUTE format('SELECT %s($1::jsonb)', handler) USING NEW.value;
            EXCEPTION WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS
                    err_sqlstate = RETURNED_SQLSTATE,
                    message  = MESSAGE_TEXT,
                    detail   = PG_EXCEPTION_DETAIL,
                    hint     = PG_EXCEPTION_HINT,
                    context  = PG_EXCEPTION_CONTEXT;

                INSERT INTO cache.handler_error_log (
                    composite_key,
                    handler,
                    payload,
                    sqlstate,
                    message,
                    detail,
                    hint,
                    context
                )
                VALUES (
                    NEW.composite_key,
                    handler,
                    NEW.value::jsonb,
                    err_sqlstate,
                    message,
                    detail,
                    hint,
                    context
                );
            END;
        END IF;

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    INSERT INTO cache.event_handlers (composite_key, handler, description, updated_at)
    VALUES
        ('structs.structs.EventAllocation.allocation', 'cache.handle_event_allocation'::regproc, 'allocation', now()),
        ('structs.structs.EventAgreement.agreement', 'cache.handle_event_agreement'::regproc, 'agreement', now()),
        ('structs.structs.EventGuild.guild', 'cache.handle_event_guild'::regproc, 'guild', now()),
        ('structs.structs.EventInfusion.infusion', 'cache.handle_event_infusion'::regproc, 'infusion', now()),
        ('structs.structs.EventFleet.fleet', 'cache.handle_event_fleet'::regproc, 'fleet', now()),
        ('structs.structs.EventPlanet.planet', 'cache.handle_event_planet'::regproc, 'planet', now()),
        ('structs.structs.EventPlayer.player', 'cache.handle_event_player'::regproc, 'player', now()),
        ('structs.structs.EventProvider.provider', 'cache.handle_event_provider'::regproc, 'provider', now()),
        ('structs.structs.EventReactor.reactor', 'cache.handle_event_reactor'::regproc, 'reactor', now()),
        ('structs.structs.EventStruct.structure', 'cache.handle_event_struct'::regproc, 'struct', now()),
        ('structs.structs.EventStructDefender.structDefender', 'cache.handle_event_struct_defender'::regproc, 'struct_defender', now()),
        ('structs.structs.EventStructDefenderClear.structDefenderClearDetail', 'cache.handle_event_struct_defender_clear'::regproc, 'struct_defender_clear', now()),
        ('structs.structs.EventStructType.structType', 'cache.handle_event_struct_type'::regproc, 'struct_type', now()),
        ('structs.structs.EventSubstation.substation', 'cache.handle_event_substation'::regproc, 'substation', now()),
        ('structs.structs.EventGuildMembershipApplication.guildMembershipApplication', 'cache.handle_event_guild_membership_application'::regproc, 'guild_membership_application', now()),
        ('structs.structs.EventAddressActivity.addressActivity', 'cache.handle_event_address_activity'::regproc, 'address_activity', now()),
        ('structs.structs.EventAddress.address', 'cache.handle_event_address'::regproc, 'address', now()),
        ('structs.structs.EventAddressAssociation.addressAssociation', 'cache.handle_event_address_association'::regproc, 'address_association', now()),
        ('structs.structs.EventPermission.permissionRecord', 'cache.handle_event_permission'::regproc, 'permission', now()),
        ('structs.structs.EventGrid.gridRecord', 'cache.handle_event_grid'::regproc, 'grid', now()),
        ('structs.structs.EventStructAttribute.structAttributeRecord', 'cache.handle_event_struct_attribute'::regproc, 'struct_attribute', now()),
        ('structs.structs.EventPlanetAttribute.planetAttributeRecord', 'cache.handle_event_planet_attribute'::regproc, 'planet_attribute', now()),
        ('structs.structs.EventAttack.eventAttackDetail', 'cache.handle_event_attack'::regproc, 'attack', now()),
        ('structs.structs.EventOreMine.eventOreMineDetail', 'cache.handle_event_ore_mine'::regproc, 'ore_mine', now()),
        ('structs.structs.EventOreMigrate.eventOreMigrateDetail', 'cache.handle_event_ore_migrate'::regproc, 'ore_migrate', now()),
        ('structs.structs.EventOreTheft.eventOreTheftDetail', 'cache.handle_event_ore_theft'::regproc, 'ore_theft', now()),
        ('structs.structs.EventAlphaRefine.eventAlphaRefineDetail', 'cache.handle_event_alpha_refine'::regproc, 'alpha_refine', now()),
        ('structs.structs.EventRaid.eventRaidDetail', 'cache.handle_event_raid'::regproc, 'raid', now()),
        ('structs.structs.EventTime.eventTimeDetail', 'cache.handle_event_time'::regproc, 'time', now()),
        ('structs.structs.EventProviderAddress.eventProviderAddressDetail', 'cache.handle_event_provider_address'::regproc, 'provider_address', now()),
        ('structs.structs.EventGuildBankAddress.eventGuildBankAddressDetail', 'cache.handle_event_guild_bank_address'::regproc, 'guild_bank_address', now())
    ON CONFLICT (composite_key) DO UPDATE
    SET
        handler = EXCLUDED.handler,
        description = EXCLUDED.description,
        updated_at = EXCLUDED.updated_at;

COMMIT;
