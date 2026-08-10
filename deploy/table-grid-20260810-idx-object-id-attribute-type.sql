-- Deploy structs-pg:table-grid-20260810-idx-object-id-attribute-type to pg
--
-- Covers the correlated (object_id, attribute_type) lookups in view.player,
-- PlayerManager, and the fuel subplan in StructManager. Without it every
-- such lookup seq-scans the whole grid table.

BEGIN;

    CREATE INDEX grid_object_id_attribute_type_idx
        ON structs.grid (object_id, attribute_type);

COMMIT;
