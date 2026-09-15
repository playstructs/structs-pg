-- Deploy structs-pg:index-catalog-20260915-updated-at-id to pg
--
-- The webapp's catalog list endpoints page through whole tables with
--
--     ... FROM structs.<table> [WHERE <filter>]
--     ORDER BY updated_at DESC NULLS LAST, id LIMIT 100 OFFSET n
--
-- and none of those tables had an index on updated_at. Every page sorted
-- the entire table; deep pages spilled the sort to disk. pg_stat_statements
-- over the first 20 hours after the 2026-09-14 restart: 13 statement shapes,
-- 34k calls, 2,172 s (52% of all statement time on the server) and 137 GB of
-- temporary files, almost all from struct (93 GB) and struct_attribute
-- (44 GB). This is the source of the ~1.1 TB cumulative temp_bytes.
--
-- Measured with the indexes (rolled-back test on production):
--   struct_attribute page 1        35 ms, 4,174 buffers  ->  0.14 ms, 36 buffers
--   struct page 500 (offset 49900) external sort, spill  ->  19 ms, no temp
--
-- Column order follows each statement's filter then its ORDER BY, so the
-- planner walks the index in output order and stops at LIMIT+OFFSET:
--   struct, struct_attribute, planet_attribute, grid, planet   (unfiltered)
--   planet_attribute WHERE attribute_type = $1
--   grid             WHERE attribute_type = $1 AND object_type = $2
-- The struct variant with "updated_at > to_timestamp($1)" is a range on the
-- same leading column and uses the unfiltered index.
--
-- Omitted on purpose: the player (guild_id), fleet and allocation shapes
-- total under 3 s in the same window. OFFSET pagination still reads every
-- skipped entry; keyset paging on (updated_at, id) is the webapp-side
-- follow-up if deep pages matter.

BEGIN;

    CREATE INDEX struct_updated_at_id_idx
        ON structs.struct (updated_at DESC NULLS LAST, id);

    CREATE INDEX struct_attribute_updated_at_id_idx
        ON structs.struct_attribute (updated_at DESC NULLS LAST, id);

    CREATE INDEX planet_attribute_updated_at_id_idx
        ON structs.planet_attribute (updated_at DESC NULLS LAST, id);

    CREATE INDEX planet_attribute_attribute_type_updated_at_id_idx
        ON structs.planet_attribute (attribute_type, updated_at DESC NULLS LAST, id);

    CREATE INDEX grid_updated_at_id_idx
        ON structs.grid (updated_at DESC NULLS LAST, id);

    CREATE INDEX grid_attribute_object_updated_at_id_idx
        ON structs.grid (attribute_type, object_type, updated_at DESC NULLS LAST, id);

    CREATE INDEX planet_updated_at_id_idx
        ON structs.planet (updated_at DESC NULLS LAST, id);

COMMIT;
