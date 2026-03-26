-- Verify structs-pg:table-reactor-20260325-add-owner on pg

BEGIN;

    SELECT owner FROM structs.reactor WHERE FALSE;

ROLLBACK;
