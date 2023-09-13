-- Deploy structs-pg:table-reactor to pg

BEGIN;

CREATE TABLE structs.reactor (
	id INTEGER PRIMARY KEY,
	validator CHARACTER VARYING,

	fuel INTEGER,
	energy INTEGER,
	load INTEGER,

	guild_id INTEGER,

	automated_allocations BOOLEAN,
	allow_manual_allocations BOOLEAN,
	allow_external_allocations BOOLEAN,
	allow_uncapped_allocations BOOLEAN,

	delegate_minimum_before_allowed_allocations NUMERIC,
	delegate_tax_on_allocations NUMERIC,

    service_substation_id INTEGER,

	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
