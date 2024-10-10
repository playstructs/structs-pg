-- Deploy structs-pg:trigger-player-pending to pg

BEGIN;
    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_MERGE()
      RETURNS trigger AS
    $BODY$
    DECLARE
        pending_data RECORD;
    BEGIN

        DELETE FROM structs.player_pending WHERE player_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;

        INSERT INTO structs.player_meta
            VALUES (NEW.id,
                    NEW.guild_id,
                    pending_data.username,
                    pending_data.pfp,
                    '',
                    NOW(),
                    NOW()
            );

        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER PLAYER_PENDING_MERGE AFTER INSERT ON structs.player
     FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_PENDING_MERGE();

COMMIT;

