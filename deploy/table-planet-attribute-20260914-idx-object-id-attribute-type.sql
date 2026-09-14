-- Deploy structs-pg:table-planet-attribute-20260914-idx-object-id-attribute-type to pg
--
-- planet_attribute only had its primary key on the composite text id
-- ('<prefix>-<planet>'), so every lookup had to rebuild that string. grid and
-- struct_attribute already carry (object_id, attribute_type); give
-- planet_attribute the same so view.work_live can join planets to their
-- shield / raid / mine / refine clocks on real columns.

BEGIN;

    CREATE INDEX planet_attribute_object_id_attribute_type_idx
        ON structs.planet_attribute (object_id, attribute_type);

COMMIT;
