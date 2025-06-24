-- Deploy structs-pg:trigger-name-planet to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.NAME_PLANET() RETURNS trigger AS
    $BODY$
    DECLARE
        _guild_id CHARACTER VARYING;
    BEGIN
        SELECT player.guild_id INTO _guild_id FROM structs.player WHERE player.id = NEW.owner;

        -- A little weird, but we don't actually name the planet here
        -- We only try to insert the row, then the default value is generated from the table declaration
        INSERT INTO structs.planet_meta(id, guild_id, created_at, updated_at)
            VALUES(
                NEW.id,
                _guild_id,
                NOW(),
                NOW()
            ) ON CONFLICT (id, guild_id) DO NOTHING;

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE TRIGGER NAME_PLANET AFTER INSERT OR UPDATE ON structs.planet
        FOR EACH ROW EXECUTE PROCEDURE structs.NAME_PLANET();

COMMIT;

