-- Revert structs-pg:table-current-block from pg

BEGIN;

DROP TABLE structs.current_block;

COMMIT;
