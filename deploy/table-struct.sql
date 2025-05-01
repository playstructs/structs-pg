-- Deploy structs-pg:table-struct to pg

BEGIN;

    CREATE  TABLE structs.struct (
        id CHARACTER VARYING PRIMARY KEY,
        index INTEGER,

        type INTEGER,
        creator CHARACTER VARYING,
        owner CHARACTER VARYING,

        location_type CHARACTER VARYING,
        location_id CHARACTER VARYING,
        operating_ambit CHARACTER VARYING,
        slot INTEGER,

        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE  TABLE structs.struct_attribute (
        id              CHARACTER VARYING PRIMARY KEY,
        object_id       CHARACTER VARYING,
        object_type     CHARACTER VARYING,
        sub_index       INTEGER,
        attribute_type  CHARACTER VARYING,
        val             INTEGER,
        updated_at	    TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE  TABLE structs.struct_defender (
        defending_struct_id   CHARACTER VARYING PRIMARY KEY,
        protected_struct_id   CHARACTER VARYING,
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );


    CREATE OR REPLACE FUNCTION structs.GET_ACTIVITY_LOCATION_ID(_struct_id CHARACTER VARYING) RETURNS CHARACTER VARYING AS
    $BODY$
    DECLARE
        _location_id CHARACTER VARYING;
        _location_type CHARACTER VARYING;
    BEGIN
        SELECT struct.location_type, struct.location_id INTO _location_type, _location_id FROM structs.struct where struct.id = _struct_id;
        IF _location_type = 'fleet' THEN
            SELECT fleet.location_id INTO _location_id FROM structs.fleet where fleet.id = _location_id;
        END IF;

        RETURN _location_id;
    END;
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;

COMMIT;
