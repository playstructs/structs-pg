-- Revert structs-pg:cache-trigger-add-queue-20260325-110b-schema-update from pg

BEGIN;

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

    DROP FUNCTION IF EXISTS cache.handle_event_guild_rank_permission(jsonb);

    DELETE FROM cache.event_handlers
    WHERE composite_key = 'structs.structs.EventGuildRankPermission.guildRankPermissionRecord';

COMMIT;
