-- Deploy structs-pg:table-provider to pg

BEGIN;

CREATE TABLE structs.provider (
	id CHARACTER VARYING PRIMARY KEY,
    index INTEGER,

    substation_id CHARACTER VARYING,

    rate_amount BIGINT,
    rate_denom CHARACTER VARYING,

    access_policy CHARACTER VARYING,

    capacity_minimum BIGINT,
    capacity_maximum BIGINT,
    duration_minimum BIGINT,
    duration_maximum BIGINT,

    provider_cancellation_penalty NUMERIC,
    consumer_cancellation_penalty NUMERIC,

    creator CHARACTER VARYING,
    owner CHARACTER VARYING,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW()
); 

COMMIT;
