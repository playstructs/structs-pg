-- Deploy structs-pg:table-current-block to pg

BEGIN;

CREATE TABLE structs.current_block (
	height BIGINT,
    updated_at	TIMESTAMPTZ NOT NULL
);

INSERT INTO structs.current_block VALUES(0, NOW());

COMMIT;
