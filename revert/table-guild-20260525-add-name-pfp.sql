-- Revert structs-pg:table-guild-20260525-add-name-pfp from pg

BEGIN;

    ALTER TABLE structs.guild
        DROP COLUMN IF EXISTS name,
        DROP COLUMN IF EXISTS pfp;

COMMIT;
