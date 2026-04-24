-- Deploy structs-pg:cache-trigger-add-queue-20260424-player-update to pg

BEGIN;

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


    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_MERGE()
        RETURNS trigger AS
    $BODY$
    DECLARE
        pending_data RECORD;
        numrows INT;
    BEGIN

        DELETE FROM structs.player_external_pending WHERE player_external_pending.primary_address = NEW.primary_address;
        DELETE FROM structs.player_pending WHERE player_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;

        get diagnostics numrows = row_count;
        IF numrows = 0 THEN
            DELETE FROM structs.player_internal_pending WHERE player_internal_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;
            get diagnostics numrows = row_count;

            IF numrows > 0 THEN
                UPDATE structs.player_discord SET player_id = NEW.id WHERE role_id=pending_data.role_id;
                UPDATE signer.role SET player_id = NEW.id, status='ready' WHERE id=pending_data.role_id;
            END IF;
        END IF;

        IF numrows > 0 THEN
            INSERT INTO structs.player_meta
            VALUES (NEW.id,
                    pending_data.guild_id,
                    pending_data.username,
                    pending_data.pfp,
                    '',
                    NOW(),
                    NOW()
                   );

        END IF;

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    update player_address set guild_id = (select player.guild_id from player where player.id = player_id);


COMMIT;
