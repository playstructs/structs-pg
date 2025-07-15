-- Revert structs-pg:table-guild from pg

BEGIN;

DROP TABLE IF EXISTS structs.guild_bank CASCADE;
DROP TABLE IF EXISTS structs.guild_membership_application CASCADE;
DROP TABLE IF EXISTS structs.guild_meta CASCADE;
DROP TABLE IF EXISTS structs.guild CASCADE;
DROP FUNCTION IF EXISTS structs.GUILD_METADATA_UPDATE(_guild_id CHARACTER VARYING, _payload JSONB);

COMMIT;
