-- Verify structs-pg:table-allocation-20260325-drop-locked on pg

BEGIN;

    SELECT id, allocation_type, source_id, index, destination_id, creator, controller, created_at, updated_at
    FROM structs.allocation WHERE FALSE;

ROLLBACK;
