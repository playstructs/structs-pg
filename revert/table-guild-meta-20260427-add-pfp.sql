-- Revert structs-pg:table-guild-meta-20260427-add-pfp from pg

BEGIN;

    ALTER TABLE structs.guild_meta
        DROP COLUMN IF EXISTS pfp;

COMMIT;
