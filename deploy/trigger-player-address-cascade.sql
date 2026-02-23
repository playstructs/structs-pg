-- Deploy structs-pg:trigger-player-address-cascade to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_ADDRESS_CASCADE()
        RETURNS trigger AS
    $BODY$
    BEGIN
        IF NEW.guild_id <> OLD.guild_id THEN
            UPDATE structs.player_address
                SET guild_id=NEW.guild_id
                WHERE player_id = NEW.id;
        END IF;

        IF TG_OP = 'INSERT' THEN
            INSERT INTO structs.player_address (
                address,
                player_id,
                guild_id,
                status,
                created_at,
                updated_at
            )
            VALUES (
                       NEW.primary_address,
                       NEW.id,
                       NEW.guild_id,
                       'approved',
                       NOW(),
                       NOW()
                   ) ON CONFLICT (address) DO UPDATE
                SET
                    status = EXCLUDED.status,
                    player_id = EXCLUDED.player_id,
                    guild_id = EXCLUDED.guild_id,
                    updated_at = EXCLUDED.updated_at
            WHERE
                    structs.player_address.status IS DISTINCT FROM EXCLUDED.status
               OR structs.player_address.player_id IS DISTINCT FROM EXCLUDED.player_id;
        END IF;

    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER PLAYER_ADDRESS_CASCADE AFTER INSERT OR UPDATE ON structs.player
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_ADDRESS_CASCADE();

COMMIT;