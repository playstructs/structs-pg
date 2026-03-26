-- Deploy structs-pg:cache-trigger-add-queue-20260325-110b-schema-update to pg

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
            x.controller AS controller
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            type text,
            "sourceObjectId" text,
            "index" integer,
            "destinationId" text,
            creator text,
            controller text
        );

        INSERT INTO structs.allocation (
            id,
            allocation_type,
            source_id,
            index,
            destination_id,
            creator,
            controller,
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
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                destination_id = EXCLUDED.destination_id,
                controller = EXCLUDED.controller,
                updated_at = NOW()
            WHERE
                structs.allocation.destination_id IS DISTINCT FROM EXCLUDED.destination_id
                OR structs.allocation.controller IS DISTINCT FROM EXCLUDED.controller;
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
            x."entryRank" AS entry_rank,
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
            "entryRank" bigint,
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
            entry_rank,
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
            v.entry_rank,
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
                entry_rank = EXCLUDED.entry_rank,
                owner = EXCLUDED.owner,
                updated_at = NOW()
            WHERE
                structs.guild.endpoint IS DISTINCT FROM EXCLUDED.endpoint
                OR structs.guild.join_infusion_minimum_p IS DISTINCT FROM EXCLUDED.join_infusion_minimum_p
                OR structs.guild.join_infusion_minimum_bypass_by_request IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_request
                OR structs.guild.join_infusion_minimum_bypass_by_invite IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_invite
                OR structs.guild.primary_reactor_id IS DISTINCT FROM EXCLUDED.primary_reactor_id
                OR structs.guild.entry_substation_id IS DISTINCT FROM EXCLUDED.entry_substation_id
                OR structs.guild.entry_rank IS DISTINCT FROM EXCLUDED.entry_rank
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
            x."fleetId" AS fleet_id,
            x."guildRank" AS guild_rank
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            "index" integer,
            creator text,
            "primaryAddress" text,
            "guildId" text,
            "substationId" text,
            "planetId" text,
            "fleetId" text,
            "guildRank" bigint
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
            guild_rank,
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
            v.guild_rank,
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
                guild_rank = EXCLUDED.guild_rank,
                updated_at = NOW()
            WHERE
                structs.player.primary_address IS DISTINCT FROM EXCLUDED.primary_address
                OR structs.player.guild_id IS DISTINCT FROM EXCLUDED.guild_id
                OR structs.player.substation_id IS DISTINCT FROM EXCLUDED.substation_id
                OR structs.player.planet_id IS DISTINCT FROM EXCLUDED.planet_id
                OR structs.player.fleet_id IS DISTINCT FROM EXCLUDED.fleet_id
                OR structs.player.guild_rank IS DISTINCT FROM EXCLUDED.guild_rank;

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
            x."defaultCommission" AS default_commission,
            x.owner AS owner
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id text,
            validator text,
            "guildId" text,
            "defaultCommission" numeric,
            owner text
        );

        INSERT INTO structs.reactor (
            id,
            validator,
            guild_id,
            default_commission,
            owner,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.validator,
            v.guild_id,
            v.default_commission,
            v.owner,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                guild_id = EXCLUDED.guild_id,
                default_commission = EXCLUDED.default_commission,
                owner = EXCLUDED.owner,
                updated_at = NOW()
            WHERE
                structs.reactor.guild_id IS DISTINCT FROM EXCLUDED.guild_id
                OR structs.reactor.default_commission IS DISTINCT FROM EXCLUDED.default_commission
                OR structs.reactor.owner IS DISTINCT FROM EXCLUDED.owner;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES(v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id=EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    CREATE OR REPLACE FUNCTION cache.handle_event_guild_rank_permission(payload jsonb)
    RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."objectId" AS object_id,
            x."guildId" AS guild_id,
            x.permissions AS permission,
            x.rank AS rank
        INTO v
        FROM jsonb_to_record(payload) AS x(
            "objectId" text,
            "guildId" text,
            permissions bigint,
            rank bigint
        );

        IF v.rank = 0 THEN
            DELETE FROM structs.permission_guild_rank
            WHERE object_id = v.object_id
              AND guild_id = v.guild_id
              AND permission = v.permission;
        ELSE
            INSERT INTO structs.permission_guild_rank (
                object_id,
                guild_id,
                permission,
                rank,
                updated_at
            )
            VALUES (
                v.object_id,
                v.guild_id,
                v.permission,
                v.rank,
                NOW()
            ) ON CONFLICT (object_id, guild_id, permission) DO UPDATE
                SET
                    rank = EXCLUDED.rank,
                    updated_at = EXCLUDED.updated_at
                WHERE
                    structs.permission_guild_rank.rank IS DISTINCT FROM EXCLUDED.rank;
        END IF;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER
    COST 100;

    INSERT INTO cache.event_handlers (composite_key, handler, description, updated_at)
    VALUES
        ('structs.structs.EventGuildRankPermission.guildRankPermissionRecord', 'cache.handle_event_guild_rank_permission'::regproc, 'guild_rank_permission', now())
    ON CONFLICT (composite_key) DO UPDATE
    SET
        handler = EXCLUDED.handler,
        description = EXCLUDED.description,
        updated_at = EXCLUDED.updated_at;

COMMIT;
