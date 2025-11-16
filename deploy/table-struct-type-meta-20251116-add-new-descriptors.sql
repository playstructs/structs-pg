-- Deploy structs-pg:table-struct-type-meta-20251116-add-new-descriptors to pg

BEGIN;

    ALTER TABLE structs.struct_type_meta ADD COLUMN model_number CHARACTER VARYING;

    ALTER TABLE structs.struct_type_meta DROP CONSTRAINT struct_type_meta_pkey;
    ALTER TABLE structs.struct_type_meta ADD CONSTRAINT struct_type_meta_pkey PRIMARY KEY (id, guild_id);

    INSERT INTO structs.struct_type_meta(id, guild_id, name, model_number, created_at, updated_at)
    SELECT
        struct_type.id,
        guild.id,
        struct_type.default_cosmetic_name,
        struct_type.default_cosmetic_model_number,
        NOW(),
        NOW()
    FROM structs.guild, structs.struct_type
        ON CONFLICT(id, guild_id) DO NOTHING;

COMMIT;
