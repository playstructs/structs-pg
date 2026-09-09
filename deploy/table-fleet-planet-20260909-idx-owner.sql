-- Deploy structs-pg:table-fleet-planet-20260909-idx-owner to pg
--
-- GET /api/planet-activity/player/{id} raid / fleet / planet half:
--   detail->>'fleet_id' IN (SELECT id FROM structs.fleet  WHERE owner = :player_id)
--   planet_id           IN (SELECT id FROM structs.planet WHERE owner = :player_id)
-- struct_id / defender_struct_id already use structs.struct_owner_idx.
-- planet.owner covers raid_status (raided half), shield_change,
-- block_raid_start, and fleet_arrive / fleet_depart.

BEGIN;

    CREATE INDEX fleet_owner_idx  ON structs.fleet  (owner);
    CREATE INDEX planet_owner_idx ON structs.planet (owner);

COMMIT;
