-- Revert structs-pg:table-reactor-20260325-add-owner from pg

BEGIN;

    ALTER TABLE structs.reactor DROP COLUMN IF EXISTS owner;

COMMIT;
