-- Revert structs-pg:type-grass-category from pg

BEGIN;

DROP TYPE structs.grass_category;

COMMIT;
