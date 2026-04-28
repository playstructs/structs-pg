-- Verify structs-pg:table-substation-20260427-add-name-pfp on pg

BEGIN;

    SELECT name, pfp FROM structs.substation WHERE FALSE;

ROLLBACK;
