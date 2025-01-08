-- Deploy structs-pg:table-current-block to pg

BEGIN;

CREATE UNLOGGED TABLE structs.current_block (
    chain TEXT PRIMARY KEY,
	height BIGINT,
    updated_at	TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
