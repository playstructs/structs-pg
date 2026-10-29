-- Deploy structs-pg:table-vault-20261029-account-origin to pg
BEGIN;
-- NULL means historical origin was not captured. Only an observed true proves
-- the release created a BaseAccount; an adopted account may restrict spending.
ALTER TABLE structs.vault ADD COLUMN account_created BOOLEAN;
COMMENT ON COLUMN structs.vault.account_created IS
    'Original EventVaultAddress accountCreated evidence. NULL is unknown, false is adopted; neither proves an unrestricted account.';
COMMIT;
