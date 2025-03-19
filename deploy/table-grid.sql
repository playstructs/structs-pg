-- Deploy structs-pg:table-grid to pg

BEGIN;

-- ID Format "%d-%d-%d", gridAttributeType, objectType, objectId
CREATE TABLE structs.grid (
    id              CHARACTER VARYING PRIMARY KEY,
    attribute_type  CHARACTER VARYING,
    object_type     CHARACTER VARYING,
    object_index    INTEGER,
    object_id       CHARACTER VARYING,
    val             NUMERIC,
    updated_at	    TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;
