-- Verify structs-pg:table-struct-defender-20260810-idx-protected-struct-id on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        IF to_regclass('structs.struct_defender_protected_struct_id_idx') IS NULL THEN
            RAISE EXCEPTION 'expected structs.struct_defender_protected_struct_id_idx to exist';
        END IF;

        SELECT pg_get_indexdef('structs.struct_defender_protected_struct_id_idx'::regclass)
        INTO def;

        IF def NOT LIKE '%(protected_struct_id, defending_struct_id)%' THEN
            RAISE EXCEPTION 'struct_defender_protected_struct_id_idx columns unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
