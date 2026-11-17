-- Revert structs-pg:influence-contest-20261117 from pg
-- A distributed contest identity, score history and grass publication must not
-- disappear when a guild rolls back its software. Use a forward migration.
BEGIN;
DO $$ BEGIN
 RAISE EXCEPTION 'contest 2 is a durable network-wide contest; use a forward migration instead of reverting it';
END $$;
ROLLBACK;
