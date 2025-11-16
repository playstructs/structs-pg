-- Revert structs-pg:table-struct-type-meta-20251116-add-new-descriptors from pg

BEGIN;

    -- I'm not going to revert this since the other way was a bug anyways.
    -- ALTER TABLE structs.struct_type_meta DROP CONSTRAINT struct_type_meta_pkey;
    -- ALTER TABLE structs.struct_type_meta ADD CONSTRAINT struct_type_meta_pkey PRIMARY KEY (id);

    ALTER TABLE structs.struct_type_meta DROP COLUMN IF EXISTS model_number;

COMMIT;
