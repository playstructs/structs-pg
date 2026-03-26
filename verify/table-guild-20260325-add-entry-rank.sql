-- Verify structs-pg:table-guild-20260325-add-entry-rank on pg

BEGIN;

    SELECT entry_rank FROM structs.guild WHERE FALSE;

ROLLBACK;
