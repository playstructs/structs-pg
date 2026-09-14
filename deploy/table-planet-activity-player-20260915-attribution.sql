-- Deploy structs-pg:table-planet-activity-player-20260915-attribution to pg
--
-- Per-player index of planet_activity, written at insert time.
--
-- structs.planet_activity has no player column; the per-player feed in the
-- webapp reconstructs attribution on every read from detail JSON and current
-- ownership, scanning every chunk (427 ms and ~1M buffers per page when this
-- was written, growing with the table). This side table holds one row per
-- (activity row, player, role), keyed so a player's feed is an index-ordered
-- LIMIT, and records ownership as it was when the event happened rather than
-- as it is at read time.
--
-- It is a hypertable on the same time column with the same 7-day chunks as
-- planet_activity so retention and compression can follow the parent.
--
-- Maintained by an AFTER INSERT trigger on planet_activity that evaluates
-- structs.planet_activity_players(). This is an index-like derivative of an
-- append-only event log, not a current-state api_* table, so the
-- "sync-state owns api_* writes, no triggers" rule from
-- docs/guild-api-database-handoff.md does not apply: sync-state's insert
-- path is unchanged and the attribution cannot drift from the log.
-- planet_activity rows are never updated in place; deletes are not
-- propagated (there is no FK across hypertables) and are handled by the
-- reconciler.

BEGIN;

    CREATE TABLE structs.planet_activity_player (
        time         TIMESTAMPTZ NOT NULL,
        planet_id    CHARACTER VARYING NOT NULL,
        seq          INTEGER NOT NULL,
        player_id    CHARACTER VARYING NOT NULL,
        role         TEXT NOT NULL
                     CHECK (role IN ('attacker', 'target', 'owner', 'planet_owner',
                                     'defender', 'protected', 'fleet_owner')),
        category     structs.grass_category,
        block_height BIGINT,
        PRIMARY KEY (time, planet_id, seq, player_id, role)
    );

    SELECT create_hypertable('structs.planet_activity_player', by_range('time', INTERVAL '7 days'));

    -- Feed order used by the webapp: block_height DESC NULLS LAST, time DESC,
    -- planet_id DESC, seq DESC (same suffix as the planet_activity read indexes).
    CREATE INDEX planet_activity_player_feed_idx
        ON structs.planet_activity_player
        (player_id, block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC);

    CREATE INDEX planet_activity_player_category_feed_idx
        ON structs.planet_activity_player
        (player_id, category, block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC);

    COMMENT ON TABLE structs.planet_activity_player IS
        'Per-player attribution of structs.planet_activity, one row per (activity row, player, role), written by the planet_activity_attribute trigger from structs.planet_activity_players(). Join back on (time, planet_id, seq). Ownership is as of the event, not as of the read.';

    CREATE OR REPLACE FUNCTION structs.planet_activity_attribute() RETURNS trigger
    LANGUAGE plpgsql
    AS
    $BODY$
    BEGIN
        INSERT INTO structs.planet_activity_player
            (time, planet_id, seq, player_id, role, category, block_height)
        SELECT NEW.time, NEW.planet_id, NEW.seq, a.player_id, a.role, NEW.category, NEW.block_height
          FROM structs.planet_activity_players(NEW.category, NEW.planet_id, NEW.detail) a
        ON CONFLICT DO NOTHING;

        RETURN NEW;
    END
    $BODY$;

    CREATE TRIGGER planet_activity_attribute
        AFTER INSERT ON structs.planet_activity
        FOR EACH ROW EXECUTE FUNCTION structs.planet_activity_attribute();

    GRANT SELECT, INSERT, UPDATE, DELETE
        ON structs.planet_activity_player
        TO structs_indexer;

    GRANT SELECT
        ON structs.planet_activity_player
        TO structs_webapp;

COMMIT;
