-- Verify structs-pg:view-struct-20260904-add-state-columns on pg

BEGIN;

    SELECT struct_id, health, status, is_built, is_online, is_destroyed,
           protected_struct_index, protected_struct_id
    FROM view.struct
    WHERE FALSE;

    DO $$
    DECLARE
        def text;
    BEGIN
        def := pg_get_viewdef('view.struct'::regclass, true);
        IF position('is_built' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct missing is_built';
        END IF;
        IF position('is_online' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct missing is_online';
        END IF;
        IF position('is_destroyed' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct missing is_destroyed';
        END IF;
        IF position('protected_struct_id' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct missing protected_struct_id';
        END IF;
    END $$;

ROLLBACK;
