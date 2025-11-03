-- Revert structs-pg:view-guild-bank from pg

BEGIN;

DROP VIEW IF EXISTS view.guild_bank CASCADE;

COMMIT;
