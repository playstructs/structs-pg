-- Verify structs-pg:table-struct-20260810-idx-owner on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        IF to_regclass('structs.struct_owner_idx') IS NULL THEN
            RAISE EXCEPTION 'expected structs.struct_owner_idx to exist';
        END IF;

        SELECT pg_get_indexdef('structs.struct_owner_idx'::regclass)
        INTO def;

        IF def NOT LIKE '%(owner)%' THEN
            RAISE EXCEPTION 'struct_owner_idx columns unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
