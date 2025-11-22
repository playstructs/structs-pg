-- Revert structs-pg:function-unique-random from pg

BEGIN;

DROP FUNCTION IF EXISTS structs.unique_human_random(int, text, text);
DROP FUNCTION IF EXISTS structs.random_human_string(int);
DROP FUNCTION IF EXISTS structs.gen_random_bytes(int);

COMMIT;

