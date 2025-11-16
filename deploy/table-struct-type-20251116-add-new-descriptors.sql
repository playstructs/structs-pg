-- Deploy structs-pg:table-struct-type-20251116-add-new-descriptors to pg

BEGIN;

    ALTER TABLE structs.struct_type ADD COLUMN class CHARACTER VARYING;
    ALTER TABLE structs.struct_type ADD COLUMN class_abbreviation CHARACTER VARYING;
    ALTER TABLE structs.struct_type ADD COLUMN default_cosmetic_model_number CHARACTER VARYING;
    ALTER TABLE structs.struct_type ADD COLUMN default_cosmetic_name CHARACTER VARYING;

    UPDATE structs.struct_type
    SET
        class =  attributes.value::JSONB->>'class',
        class_abbreviation =  attributes.value::JSONB->>'classAbbreviation',
        default_cosmetic_model_number =  attributes.value::JSONB->>'defaultCosmeticModelNumber',
        default_cosmetic_name =  attributes.value::JSONB->>'defaultCosmeticName'
    FROM cache.attributes
    WHERE attributes.key = 'structType' AND struct_type.id =  (attributes.value::JSONB->>'id')::INTEGER;

COMMIT;
