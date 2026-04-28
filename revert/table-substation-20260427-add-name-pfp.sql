-- Revert structs-pg:table-substation-20260427-add-name-pfp from pg

BEGIN;

    ALTER TABLE structs.substation
        DROP COLUMN IF EXISTS name,
        DROP COLUMN IF EXISTS pfp;

COMMIT;
