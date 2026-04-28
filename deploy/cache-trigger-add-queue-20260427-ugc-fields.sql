-- Deploy structs-pg:cache-trigger-add-queue-20260427-ugc-fields to pg
--
-- structsd v0.16.0 introduced chain-side UGC for the four nameable objects:
--   Player.name      Player.pfp
--   Guild.name       Guild.pfp
--   Substation.name  Substation.pfp
--   Planet.name
--
-- Update the cache event handlers to extract these fields from the chain
-- payload and persist them:
--   - structs.player_meta   (via upsert keyed on id; guild_id kept in sync)
--   - structs.guild_meta    (via upsert keyed on id)
--   - structs.substation    (columns added directly; no separate meta table)
--   - structs.planet_meta   (only when chain sends a non-empty name, so the
--                            structs.generate_planet_name() default is preserved)

BEGIN;

    -- =========================================================================
    -- handle_event_player: also persists chain UGC into structs.player_meta
    -- =========================================================================

    CREATE OR REPLACE FUNCTION cache.handle_event_player(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id              AS id,
            x."index"         AS index,
            x.creator         AS creator,
            x."primaryAddress" AS primary_address,
            x."guildId"       AS guild_id,
            x."substationId"  AS substation_id,
            x."planetId"      AS planet_id,
            x."fleetId"       AS fleet_id,
            x.name            AS name,
            x.pfp             AS pfp
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id              text,
            "index"         integer,
            creator         text,
            "primaryAddress" text,
            "guildId"       text,
            "substationId"  text,
            "planetId"      text,
            "fleetId"       text,
            name            text,
            pfp             text
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
                    guild_id        = EXCLUDED.guild_id,
                    substation_id   = EXCLUDED.substation_id,
                    planet_id       = EXCLUDED.planet_id,
                    fleet_id        = EXCLUDED.fleet_id,
                    updated_at      = NOW()
                WHERE
                       structs.player.primary_address IS DISTINCT FROM EXCLUDED.primary_address
                    OR structs.player.guild_id        IS DISTINCT FROM EXCLUDED.guild_id
                    OR structs.player.substation_id   IS DISTINCT FROM EXCLUDED.substation_id
                    OR structs.player.planet_id       IS DISTINCT FROM EXCLUDED.planet_id
                    OR structs.player.fleet_id        IS DISTINCT FROM EXCLUDED.fleet_id;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES (v.id, v.id)
            ON CONFLICT (object_id) DO UPDATE SET player_id = EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;

        INSERT INTO structs.player_meta (
            id,
            guild_id,
            username,
            pfp,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.guild_id,
            v.name,
            v.pfp,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                guild_id   = EXCLUDED.guild_id,
                username   = EXCLUDED.username,
                pfp        = EXCLUDED.pfp,
                updated_at = NOW()
            WHERE
                   structs.player_meta.guild_id IS DISTINCT FROM EXCLUDED.guild_id
                OR structs.player_meta.username IS DISTINCT FROM EXCLUDED.username
                OR structs.player_meta.pfp      IS DISTINCT FROM EXCLUDED.pfp;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    -- =========================================================================
    -- handle_event_guild: also persists chain UGC (name, pfp) into guild_meta
    -- =========================================================================

    CREATE OR REPLACE FUNCTION cache.handle_event_guild(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id                                    AS id,
            x."index"                               AS index,
            x.endpoint                              AS endpoint,
            x."joinInfusionMinimum"                 AS join_infusion_minimum,
            x."joinInfusionMinimumBypassByRequest"  AS join_infusion_minimum_bypass_by_request,
            x."joinInfusionMinimumBypassByInvite"   AS join_infusion_minimum_bypass_by_invite,
            x."primaryReactorId"                    AS primary_reactor_id,
            x."entrySubstationId"                   AS entry_substation_id,
            x."entryRank"                           AS entry_rank,
            x.creator                               AS creator,
            x.owner                                 AS owner,
            x.name                                  AS name,
            x.pfp                                   AS pfp
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id                                    text,
            "index"                               integer,
            endpoint                              text,
            "joinInfusionMinimum"                 integer,
            "joinInfusionMinimumBypassByRequest"  text,
            "joinInfusionMinimumBypassByInvite"   text,
            "primaryReactorId"                    text,
            "entrySubstationId"                   text,
            "entryRank"                           bigint,
            creator                               text,
            owner                                 text,
            name                                  text,
            pfp                                   text
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
                endpoint                                = EXCLUDED.endpoint,
                join_infusion_minimum_p                 = EXCLUDED.join_infusion_minimum_p,
                join_infusion_minimum_bypass_by_request = EXCLUDED.join_infusion_minimum_bypass_by_request,
                join_infusion_minimum_bypass_by_invite  = EXCLUDED.join_infusion_minimum_bypass_by_invite,
                primary_reactor_id                      = EXCLUDED.primary_reactor_id,
                entry_substation_id                     = EXCLUDED.entry_substation_id,
                entry_rank                              = EXCLUDED.entry_rank,
                owner                                   = EXCLUDED.owner,
                updated_at                              = NOW()
            WHERE
                   structs.guild.endpoint                              IS DISTINCT FROM EXCLUDED.endpoint
                OR structs.guild.join_infusion_minimum_p               IS DISTINCT FROM EXCLUDED.join_infusion_minimum_p
                OR structs.guild.join_infusion_minimum_bypass_by_request IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_request
                OR structs.guild.join_infusion_minimum_bypass_by_invite  IS DISTINCT FROM EXCLUDED.join_infusion_minimum_bypass_by_invite
                OR structs.guild.primary_reactor_id                    IS DISTINCT FROM EXCLUDED.primary_reactor_id
                OR structs.guild.entry_substation_id                   IS DISTINCT FROM EXCLUDED.entry_substation_id
                OR structs.guild.entry_rank                            IS DISTINCT FROM EXCLUDED.entry_rank
                OR structs.guild.owner                                 IS DISTINCT FROM EXCLUDED.owner;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES (v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id = EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;

        INSERT INTO structs.guild_meta (
            id,
            name,
            pfp,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.name,
            v.pfp,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                name       = EXCLUDED.name,
                pfp        = EXCLUDED.pfp,
                updated_at = NOW()
            WHERE
                   structs.guild_meta.name IS DISTINCT FROM EXCLUDED.name
                OR structs.guild_meta.pfp  IS DISTINCT FROM EXCLUDED.pfp;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    -- =========================================================================
    -- handle_event_substation: name and pfp now live directly on substation
    -- =========================================================================

    CREATE OR REPLACE FUNCTION cache.handle_event_substation(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT *
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id      text,
            owner   text,
            creator text,
            name    text,
            pfp     text
        );

        INSERT INTO structs.substation (
            id,
            owner,
            creator,
            name,
            pfp,
            created_at,
            updated_at
        )
        VALUES (
            v.id,
            v.owner,
            v.creator,
            v.name,
            v.pfp,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE
            SET
                owner      = EXCLUDED.owner,
                name       = EXCLUDED.name,
                pfp        = EXCLUDED.pfp,
                updated_at = NOW()
            WHERE
                   structs.substation.owner IS DISTINCT FROM EXCLUDED.owner
                OR structs.substation.name  IS DISTINCT FROM EXCLUDED.name
                OR structs.substation.pfp   IS DISTINCT FROM EXCLUDED.pfp;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES (v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id = EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    -- =========================================================================
    -- handle_event_planet: only update planet_meta.name when chain sends a
    -- non-empty value, preserving the structs.generate_planet_name() default
    -- =========================================================================

    CREATE OR REPLACE FUNCTION cache.handle_event_planet(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x.id                  AS id,
            x."maxOre"            AS max_ore,
            x.creator             AS creator,
            x.owner               AS owner,
            x.space               AS space,
            x.air                 AS air,
            x.land                AS land,
            x.water               AS water,
            x."spaceSlots"        AS space_slots,
            x."airSlots"          AS air_slots,
            x."landSlots"         AS land_slots,
            x."waterSlots"        AS water_slots,
            x.status              AS status,
            x."locationListStart" AS location_list_start,
            x."locationListEnd"   AS location_list_end,
            x.name                AS name
        INTO v
        FROM jsonb_to_record(payload) AS x(
            id                  text,
            "maxOre"            integer,
            creator             text,
            owner               text,
            space               jsonb,
            air                 jsonb,
            land                jsonb,
            water               jsonb,
            "spaceSlots"        integer,
            "airSlots"          integer,
            "landSlots"         integer,
            "waterSlots"        integer,
            status              text,
            "locationListStart" text,
            "locationListEnd"   text,
            name                text
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
                owner               = EXCLUDED.owner,
                map                 = jsonb_build_object('space', EXCLUDED.map->'space') || jsonb_build_object('air', EXCLUDED.map->'air') || jsonb_build_object('land', EXCLUDED.map->'land') || jsonb_build_object('water', EXCLUDED.map->'water'),
                status              = EXCLUDED.status,
                location_list_start = EXCLUDED.location_list_start,
                location_list_end   = EXCLUDED.location_list_end,
                updated_at          = NOW()
            WHERE
                   structs.planet.owner               IS DISTINCT FROM EXCLUDED.owner
                OR structs.planet.map                 IS DISTINCT FROM EXCLUDED.map
                OR structs.planet.status              IS DISTINCT FROM EXCLUDED.status
                OR structs.planet.location_list_start IS DISTINCT FROM EXCLUDED.location_list_start
                OR structs.planet.location_list_end   IS DISTINCT FROM EXCLUDED.location_list_end;

        INSERT INTO structs.player_object(object_id, player_id)
            VALUES (v.id, v.owner)
            ON CONFLICT (object_id) DO UPDATE SET player_id = EXCLUDED.player_id
            WHERE structs.player_object.player_id IS DISTINCT FROM EXCLUDED.player_id;

        -- planet_meta is keyed on (id, guild_id); the NAME_PLANET trigger on
        -- structs.planet inserts the row with the owner's current guild_id and
        -- relies on the column DEFAULT to generate a random name. Only stomp
        -- that name when the chain explicitly sends a non-empty value.
        IF v.name IS NOT NULL AND v.name <> '' THEN
            UPDATE structs.planet_meta
                SET name       = v.name,
                    updated_at = NOW()
                WHERE id = v.id
                  AND name IS DISTINCT FROM v.name;
        END IF;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
