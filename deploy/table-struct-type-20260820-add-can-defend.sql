-- Deploy structs-pg:table-struct-type-20260820-add-can-defend to pg
--
-- can_defend is indexer-owned metadata and is not present on chain. The
-- database default covers existing and newly imported struct types.

BEGIN;

    ALTER TABLE structs.struct_type
        ADD COLUMN can_defend BOOLEAN NOT NULL DEFAULT false;

COMMIT;
