-- Deploy structs-pg:table-planet-activity-20260820-api-cursor-unique to pg
--
-- seq is unique within a planet. Including time satisfies TimescaleDB's
-- unique-index requirement and enforces a durable activity event key.

BEGIN;

    CREATE UNIQUE INDEX planet_activity_time_planet_seq_uidx
        ON structs.planet_activity (time, planet_id, seq);

COMMIT;
