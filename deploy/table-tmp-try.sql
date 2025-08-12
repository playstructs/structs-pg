-- Deploy structs-pg:table-tmp-try to pg

BEGIN;

CREATE TABLE structs.tmp_try (
	id CHARACTER VARYING PRIMARY KEY
);

COMMIT;
