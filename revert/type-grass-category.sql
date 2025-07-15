-- Revert structs-pg:type-grass-category from pg

BEGIN;

DROP TYPE IF EXISTS structs.grass_category;

COMMIT;
