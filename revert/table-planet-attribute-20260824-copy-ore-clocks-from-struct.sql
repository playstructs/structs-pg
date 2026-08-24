-- Revert structs-pg:table-planet-attribute-20260824-copy-ore-clocks-from-struct from pg
--
-- This backfill is not reversed. Deleting planet attributes 12–15 would also
-- drop rows written by the v0.21.0 chain indexer, which are the source of
-- truth after upgrade.

BEGIN;

COMMIT;
