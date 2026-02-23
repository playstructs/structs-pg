-- Deploy structs-pg:cache-trigger-add-queue-20260223-add-player-address to pg

BEGIN;

    CREATE OR REPLACE FUNCTION cache.handle_event_address_association(payload jsonb)
        RETURNS void AS
    $BODY$
    DECLARE
        v record;
        check_count INTEGER;
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

        SELECT COUNT(1) INTO check_count FROM structs.player WHERE id = ('1-' || v.player_index::CHARACTER VARYING);
        IF check_count > 0 THEN
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
        END IF;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;


COMMIT;