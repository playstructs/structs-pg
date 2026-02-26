-- Deploy structs-pg:cache-trigger-add-queue-20260226-add-seized-ore-better to pg

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
            x."seized_ore" as seized_ore
        INTO v
        FROM jsonb_to_record(payload) AS x(
                                           "fleetId" text,
                                           "planetId" text,
                                           status text,
                                          "seized_ore" numeric
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

COMMIT;