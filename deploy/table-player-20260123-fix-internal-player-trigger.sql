-- Deploy structs-pg:table-player-20260123-fix-internal-player-trigger to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.GUILD_SIGNING_AGENT()
        RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO structs.player_internal_pending(username, guild_id) VALUES (NEW.id, NEW.id) ON CONFLICT(username) DO NOTHING;
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;


COMMIT;
