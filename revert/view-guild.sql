-- Revert structs-pg:view-guild from pg

BEGIN;

DROP VIEW view.guild;

COMMIT;
