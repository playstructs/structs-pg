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

COMMIT;
