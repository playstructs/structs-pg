-- Revert structs-pg:table-vault-20261029-account-origin from pg
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.vault WHERE account_created IS NOT NULL) THEN
        RAISE EXCEPTION 'vault origin evidence is populated; restore the coordinated checkpoint to downgrade';
    END IF;
END $$;
ALTER TABLE structs.vault DROP COLUMN account_created;
COMMIT;
