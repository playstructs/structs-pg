-- Verify structs-pg:table-guild-meta-20260427-add-pfp on pg

BEGIN;

    SELECT pfp FROM structs.guild_meta WHERE FALSE;

ROLLBACK;
