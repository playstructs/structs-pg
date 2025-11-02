-- Revert structs-pg:table-address-tag from pg

BEGIN;

DROP TABLE IF EXISTS structs.address_tag CASCADE;

COMMIT;
