-- Deploy structs-pg:table-reactor-20260325-add-owner to pg

BEGIN;

    ALTER TABLE structs.reactor ADD COLUMN owner CHARACTER VARYING;

COMMIT;
