-- Deploy structs-pg:table-struct-defender-20260810-add-is-planetary to pg
--
-- Marks defender records that protect a planetary struct, so consumers do not
-- have to join back to structs.struct on every read. Backfilled true wherever
-- the protected struct currently sits on a planet (location_type = 'planet').
--
-- The backfill is a point-in-time snapshot. cache.handle_event_struct_defender
-- was dropped with the cache schema in retire-cache-20260522, so sync-state
-- writes structs.struct_defender directly and owns keeping is_planetary
-- current going forward.

BEGIN;

    ALTER TABLE structs.struct_defender
        ADD COLUMN is_planetary BOOLEAN NOT NULL DEFAULT false;

    UPDATE structs.struct_defender SET is_planetary = true
     WHERE EXISTS (SELECT FROM structs.struct
                    WHERE struct.id = struct_defender.protected_struct_id
                      AND struct.location_type = 'planet');

COMMIT;
