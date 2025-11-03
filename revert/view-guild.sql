-- Revert structs-pg:view-guild from pg

BEGIN;

DROP VIEW IF EXISTS view.guild_inventory CASCADE;
DROP VIEW IF EXISTS view.guild CASCADE;

COMMIT;
