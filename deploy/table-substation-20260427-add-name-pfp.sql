-- Deploy structs-pg:table-substation-20260427-add-name-pfp to pg

BEGIN;

    ALTER TABLE structs.substation
        ADD COLUMN name CHARACTER VARYING,
        ADD COLUMN pfp  CHARACTER VARYING;

COMMIT;
