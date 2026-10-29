-- Verify structs-pg:table-vault-20261029-account-origin on pg
BEGIN;
SELECT owner_id,account_created FROM structs.vault WHERE FALSE;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='structs.vault'::regclass
        AND attname='account_created' AND atttypid='boolean'::regtype AND NOT attnotnull AND NOT atthasdef) THEN
        RAISE EXCEPTION 'vault account origin must be nullable without an invented default';
    END IF;
END $$;
ROLLBACK;
