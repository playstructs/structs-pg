-- Revert structs-pg:influence-official-contest-20261120 from pg
BEGIN;
DO $$ BEGIN
 RAISE EXCEPTION 'official contest reset cannot restore deleted test data; use a forward migration';
END $$;
ROLLBACK;
