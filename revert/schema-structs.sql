-- Revert structs-pg:schema-structs from pg

BEGIN;

DROP SCHEMA structs;

COMMIT;
