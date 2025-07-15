-- Revert structs-pg:table-current-block from pg

BEGIN;

DROP TABLE IF EXISTS structs.current_block CASCADE;

COMMIT;
