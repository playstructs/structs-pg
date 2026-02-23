-- Deploy structs-pg:cache-trigger-add-queue-20260221-add-seized-ore to pg

BEGIN;

    CREATE OR REPLACE FUNCTION cache.handle_event_raid(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
    BEGIN
        SELECT
            x."fleetId" AS fleet_id,
            x."planetId" AS planet_id,
            x.status AS status,
            x."seizedOre" as seized_ore
        INTO v
        FROM jsonb_to_record(payload) AS x(
                                           "fleetId" text,
                                           "planetId" text,
                                           status text,
                                          "seizedOre" numeric
            );

        INSERT INTO structs.planet_raid (fleet_id, planet_id, status, seized_ore, updated_at)
        VALUES (
                   v.fleet_id,
                   v.planet_id,
                   v.status,
                   v.seized_ore,
                   NOW()
               ) ON CONFLICT (planet_id) DO UPDATE
            SET
                fleet_id = EXCLUDED.fleet_id,
                status = EXCLUDED.status,
                seized_ore = EXCLUDED.seized_ore,
                updated_at = EXCLUDED.updated_at
        WHERE
                structs.planet_raid.fleet_id IS DISTINCT FROM EXCLUDED.fleet_id
           OR structs.planet_raid.status IS DISTINCT FROM EXCLUDED.status;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_RAID_STATUS() RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(NEW.planet_id), NEW.planet_id, 'raid_status',
                jsonb_build_object( 'planet_id', NEW.planet_id,
                                    'fleet_id', NEW.fleet_id,
                                    'status', NEW.status,
                                    'seized_ore', NEW.seized_ore)
               );
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;