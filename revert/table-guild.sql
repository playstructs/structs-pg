-- Revert structs-pg:table-guild from pg

BEGIN;

DROP TABLE structs.guild;

DROP TABLE structs.guild_meta;

COMMIT;
