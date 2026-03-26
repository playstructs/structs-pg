-- Deploy structs-pg:table-guild-20260325-add-entry-rank to pg

BEGIN;

    ALTER TABLE structs.guild ADD COLUMN entry_rank BIGINT;

COMMIT;
