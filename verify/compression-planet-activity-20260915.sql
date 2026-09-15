-- Verify structs-pg:compression-planet-activity-20260915 on pg

BEGIN;

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.hypertables
             WHERE hypertable_schema = 'structs' AND hypertable_name = 'planet_activity'
               AND compression_enabled
        ) THEN
            RAISE EXCEPTION 'compression is not enabled on structs.planet_activity';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.jobs
             WHERE hypertable_schema = 'structs' AND hypertable_name = 'planet_activity'
               AND proc_name = 'policy_compression'
        ) THEN
            RAISE EXCEPTION 'no compression policy on structs.planet_activity';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.hypertable_compression_settings
             WHERE hypertable = 'structs.planet_activity'::regclass
               AND segmentby = 'planet_id'
        ) THEN
            RAISE EXCEPTION 'planet_activity compression is not segmented by planet_id';
        END IF;
    END
    $$;

ROLLBACK;
