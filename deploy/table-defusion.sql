-- Deploy structs-pg:table-defusion to pg

BEGIN;

    CREATE  TABLE structs.defusion (
        validator_address CHARACTER VARYING,
        delegator_address CHARACTER VARYING,
        defusion_type     CHARACTER VARYING,
        amount_p          NUMERIC,
        amount            NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(amount_p, 'ualpha')) STORED,
        denom             CHARACTER VARYING,
        completed_at      TIMESTAMPTZ DEFAULT NOW(),
        created_at        TIMESTAMPTZ DEFAULT NOW()
    );


    CREATE OR REPLACE PROCEDURE structs.CLEAN_DEFUSION()
    AS
    $BODY$
    BEGIN
        DELETE FROM structs.defusion WHERE completed_at < NOW();
    END
    $BODY$ LANGUAGE plpgsql SECURITY DEFINER;

    SELECT cron.schedule('defusion_cleaner', '300 seconds', 'CALL structs.CLEAN_DEFUSION();');
COMMIT;
