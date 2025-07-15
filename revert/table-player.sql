-- Revert structs-pg:table-player from pg

BEGIN;

DROP TRIGGER IF EXISTS GUILD_SIGNING_AGENT ON structs.guild;
DROP TRIGGER IF EXISTS DISCORD_PLAYER_SIGNING_AGENT ON structs.player_discord;

DROP FUNCTION IF EXISTS structs.SET_PLAYER_INTERNAL_PENDING_PROXY(_guild_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING);
DROP FUNCTION IF EXISTS structs.GUILD_SIGNING_AGENT();
DROP FUNCTION IF EXISTS structs.DISCORD_PLAYER_SIGNING_AGENT();

DROP TABLE IF EXISTS structs.player_discord CASCADE;
DROP TABLE IF EXISTS structs.player_object CASCADE;
DROP TABLE IF EXISTS structs.player_external_pending CASCADE;
DROP INDEX IF EXISTS player_address_activation_code_idx;
DROP TABLE IF EXISTS structs.player_address_activation_code CASCADE;
DROP TABLE IF EXISTS structs.player_address_pending CASCADE;
DROP TABLE IF EXISTS structs.player_address_meta CASCADE;
DROP TABLE IF EXISTS structs.player_address_activity CASCADE;
DROP TABLE IF EXISTS structs.player_address CASCADE;
DROP TABLE IF EXISTS structs.player_internal_pending CASCADE;
DROP TABLE IF EXISTS structs.player_pending CASCADE;
DROP TABLE IF EXISTS structs.player_meta CASCADE;
DROP TABLE IF EXISTS structs.player CASCADE;

COMMIT;
