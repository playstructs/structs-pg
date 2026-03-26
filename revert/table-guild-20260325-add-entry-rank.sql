-- Revert structs-pg:table-guild-20260325-add-entry-rank from pg

BEGIN;

    ALTER TABLE structs.guild DROP COLUMN IF EXISTS entry_rank;

COMMIT;
