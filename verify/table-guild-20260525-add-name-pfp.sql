-- Verify structs-pg:table-guild-20260525-add-name-pfp on pg

BEGIN;

    SELECT name, pfp FROM structs.guild WHERE FALSE;

ROLLBACK;
