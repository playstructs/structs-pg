-- Deploy structs-pg:table-struct-defender-20260810-idx-protected-struct-id to pg
--
-- The defending_struct_ids subquery filters on protected_struct_id and
-- aggregates defending_struct_id ORDER BY defending_struct_id. A composite
-- (protected_struct_id, defending_struct_id) covers both the filter and the
-- ORDER BY, removing the Sort node that currently follows the seq scan.

BEGIN;

    CREATE INDEX struct_defender_protected_struct_id_idx
        ON structs.struct_defender (protected_struct_id, defending_struct_id);

COMMIT;
