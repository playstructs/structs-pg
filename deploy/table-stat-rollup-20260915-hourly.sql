-- Deploy structs-pg:table-stat-rollup-20260915-hourly to pg
--
-- Hourly totals for the stat_* series, so the webapp's chart endpoint reads a
-- bounded range of a small table instead of reconstructing last-known values
-- from change-triggered samples on every request.
--
-- The stat_* hypertables record an object's value only when it changes. To
-- chart "total ore across all planets per hour" the webapp (StatReadManager)
-- rebuilds the last-known value of every object at every bucket close with a
-- seed CTE that scans all history before the window: 300 ms and ~108k
-- buffers for a 7-day chart, unbounded growth. But the last-known value of
-- every object *right now* is simply the current state in structs.grid and
-- structs.struct_attribute. So:
--
--   structs.stat_rollup_snapshot(bucket)  every hour at :02, sums current
--       state per metric and object type and stores it as the bucket that
--       just closed (a value as of 13:02 is the close of the 12:00 bucket).
--   structs.stat_rollup_backfill(metric, from, to)  one-time, runs the
--       webapp's LOCF computation hourly over history so the series has no
--       gap before the first snapshot. Rows are tagged source = 'backfill'.
--
-- structs.stat_rollup_metric maps each metric to its sample table and its
-- current-state source; it is the database-side copy of FAMILY_ONE_TABLES /
-- FAMILY_TWO_TABLES in the webapp.
--
-- Semantics note: population from a snapshot is "objects currently carrying
-- the attribute"; population from the backfill is "objects that had reported
-- at least once by that hour" (the webapp's definition). They agree unless
-- objects disappear from grid / struct_attribute, so there can be a small
-- step at the backfill/snapshot seam. sum is comparable throughout.

BEGIN;

    CREATE TABLE structs.stat_rollup_metric (
        metric         TEXT PRIMARY KEY,
        stat_table     TEXT NOT NULL,                -- structs.stat_* sample table
        family         SMALLINT NOT NULL CHECK (family IN (1, 2)),
                                                    -- 1: sample table has object_type; 2: single implicit type
        source_table   TEXT NOT NULL CHECK (source_table IN ('grid', 'struct_attribute')),
        attribute_type TEXT NOT NULL,                -- attribute_type in the source table
        object_type    structs.object_type           -- family 2 only: the implicit object type
    );

    INSERT INTO structs.stat_rollup_metric (metric, stat_table, family, source_table, attribute_type, object_type) VALUES
        ('ore',                 'structs.stat_ore',                 1, 'grid',             'ore',                NULL),
        ('fuel',                'structs.stat_fuel',                1, 'grid',             'fuel',               NULL),
        ('capacity',            'structs.stat_capacity',            1, 'grid',             'capacity',           NULL),
        ('load',                'structs.stat_load',                1, 'grid',             'load',               NULL),
        ('power',               'structs.stat_power',               1, 'grid',             'power',              NULL),
        ('structs_load',        'structs.stat_structs_load',        2, 'grid',             'structsLoad',        'player'),
        ('connection_count',    'structs.stat_connection_count',    2, 'grid',             'connectionCount',    'substation'),
        ('connection_capacity', 'structs.stat_connection_capacity', 2, 'grid',             'connectionCapacity', 'substation'),
        ('struct_health',       'structs.stat_struct_health',       2, 'struct_attribute', 'health',             'struct'),
        ('struct_status',       'structs.stat_struct_status',       2, 'struct_attribute', 'status',             'struct');

    CREATE TABLE structs.stat_rollup (
        bucket      TIMESTAMPTZ NOT NULL,
        metric      TEXT NOT NULL REFERENCES structs.stat_rollup_metric (metric),
        object_type structs.object_type NOT NULL,
        sum         NUMERIC NOT NULL,
        population  BIGINT NOT NULL,
        samples     BIGINT NOT NULL,
        source      TEXT NOT NULL CHECK (source IN ('snapshot', 'backfill')),
        PRIMARY KEY (metric, object_type, bucket)
    );

    COMMENT ON TABLE structs.stat_rollup IS
        'Hourly totals of the stat_* series per metric and object type: sum of last-known values at bucket close, number of objects, number of samples in the hour. Written hourly by structs.stat_rollup_snapshot(); history from structs.stat_rollup_backfill(). avg = sum / population.';

    ---------------------------------------------------------------------------
    -- Hourly snapshot from current state
    ---------------------------------------------------------------------------
    CREATE OR REPLACE FUNCTION structs.stat_rollup_snapshot(
        p_bucket TIMESTAMPTZ DEFAULT date_trunc('hour', now()) - INTERVAL '1 hour'
    )
    RETURNS BIGINT
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        m        RECORD;
        v_rows   BIGINT;
        v_total  BIGINT := 0;
    BEGIN
        FOR m IN SELECT * FROM structs.stat_rollup_metric ORDER BY metric LOOP
            IF m.source_table = 'grid' THEN
                EXECUTE format($q$
                    INSERT INTO structs.stat_rollup (bucket, metric, object_type, sum, population, samples, source)
                    SELECT $1, %L, g.object_type::structs.object_type,
                           COALESCE(sum(g.val), 0), count(*),
                           (SELECT count(*) FROM %s s
                             WHERE s.time >= $1 AND s.time < $1 + INTERVAL '1 hour' %s),
                           'snapshot'
                      FROM structs.grid g
                     WHERE g.attribute_type = %L
                       AND g.object_type IN (SELECT unnest(enum_range(NULL::structs.object_type))::text)
                     GROUP BY g.object_type
                    ON CONFLICT (metric, object_type, bucket) DO UPDATE
                       SET sum = EXCLUDED.sum, population = EXCLUDED.population,
                           samples = EXCLUDED.samples, source = EXCLUDED.source
                $q$,
                    m.metric, m.stat_table,
                    CASE WHEN m.family = 1
                         THEN 'AND s.object_type = g.object_type::structs.object_type'
                         ELSE '' END,
                    m.attribute_type)
                USING p_bucket;
            ELSE
                EXECUTE format($q$
                    INSERT INTO structs.stat_rollup (bucket, metric, object_type, sum, population, samples, source)
                    SELECT $1, %L, %L::structs.object_type,
                           COALESCE(sum(sa.val), 0), count(*),
                           (SELECT count(*) FROM %s s
                             WHERE s.time >= $1 AND s.time < $1 + INTERVAL '1 hour'),
                           'snapshot'
                      FROM structs.struct_attribute sa
                     WHERE sa.attribute_type = %L
                    ON CONFLICT (metric, object_type, bucket) DO UPDATE
                       SET sum = EXCLUDED.sum, population = EXCLUDED.population,
                           samples = EXCLUDED.samples, source = EXCLUDED.source
                $q$,
                    m.metric, m.object_type, m.stat_table, m.attribute_type)
                USING p_bucket;
            END IF;
            GET DIAGNOSTICS v_rows = ROW_COUNT;
            v_total := v_total + v_rows;
        END LOOP;
        RETURN v_total;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.stat_rollup_snapshot(TIMESTAMPTZ) IS
        'Write one structs.stat_rollup row per (metric, object_type) for p_bucket from current grid / struct_attribute state. Default bucket: the hour that just closed. Idempotent (upsert).';

    ---------------------------------------------------------------------------
    -- One-time history from the change-triggered samples (webapp LOCF logic)
    ---------------------------------------------------------------------------
    CREATE OR REPLACE FUNCTION structs.stat_rollup_backfill(
        p_metric TEXT,
        p_from   TIMESTAMPTZ DEFAULT NULL,   -- NULL: first sample in the table
        p_to     TIMESTAMPTZ DEFAULT now()
    )
    RETURNS BIGINT
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        m            RECORD;
        v_type       structs.object_type;
        v_types      structs.object_type[];
        v_from       TIMESTAMPTZ := p_from;
        v_rows       BIGINT;
        v_total      BIGINT := 0;
        v_typefilter TEXT;
    BEGIN
        SELECT * INTO m FROM structs.stat_rollup_metric WHERE metric = p_metric;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'stat_rollup_backfill: unknown metric %', p_metric;
        END IF;

        IF v_from IS NULL THEN
            EXECUTE format('SELECT min(time) FROM %s', m.stat_table) INTO v_from;
            IF v_from IS NULL THEN
                RETURN 0;
            END IF;
        END IF;

        IF m.family = 1 THEN
            EXECUTE format('SELECT array_agg(DISTINCT object_type) FROM %s', m.stat_table) INTO v_types;
        ELSE
            v_types := ARRAY[m.object_type];
        END IF;

        FOREACH v_type IN ARRAY COALESCE(v_types, '{}') LOOP
            v_typefilter := CASE WHEN m.family = 1
                                 THEN format('AND s.object_type = %L::structs.object_type', v_type)
                                 ELSE '' END;

            EXECUTE format($q$
                WITH bounds AS (
                    SELECT date_trunc('hour', $1) AS b0,
                           date_trunc('hour', $2) AS bn,
                           INTERVAL '1 hour'      AS step
                ),
                buckets AS (
                    SELECT generate_series(b0, bn, step) AS bucket FROM bounds
                ),
                seed AS (
                    SELECT DISTINCT ON (s.object_index)
                           (SELECT b0 FROM bounds) AS bucket, s.object_index, s.value
                      FROM %1$s s
                     WHERE s.time < (SELECT b0 + step FROM bounds) %2$s
                     ORDER BY s.object_index, s.time DESC
                ),
                in_range AS (
                    SELECT DISTINCT ON (date_trunc('hour', s.time), s.object_index)
                           date_trunc('hour', s.time) AS bucket, s.object_index, s.value
                      FROM %1$s s
                     WHERE s.time >= (SELECT b0 + step FROM bounds)
                       AND s.time <  (SELECT bn + step FROM bounds) %2$s
                     ORDER BY date_trunc('hour', s.time), s.object_index, s.time DESC
                ),
                observations AS (
                    SELECT * FROM seed UNION ALL SELECT * FROM in_range
                ),
                deltas AS (
                    SELECT bucket,
                           value - COALESCE(lag(value) OVER w, 0) AS delta,
                           CASE WHEN lag(value) OVER w IS NULL THEN 1 ELSE 0 END AS is_new
                      FROM observations
                    WINDOW w AS (PARTITION BY object_index ORDER BY bucket)
                ),
                per_bucket AS (
                    SELECT bucket, SUM(delta) AS delta_sum, SUM(is_new) AS new_objects
                      FROM deltas GROUP BY bucket
                ),
                sample_counts AS (
                    SELECT date_trunc('hour', s.time) AS bucket, count(*) AS samples
                      FROM %1$s s
                     WHERE s.time >= (SELECT b0 FROM bounds)
                       AND s.time <  (SELECT bn + step FROM bounds) %2$s
                     GROUP BY 1
                ),
                rolled AS (
                    SELECT b.bucket,
                           SUM(COALESCE(pb.delta_sum, 0))   OVER (ORDER BY b.bucket) AS total,
                           SUM(COALESCE(pb.new_objects, 0)) OVER (ORDER BY b.bucket) AS population,
                           COALESCE(sc.samples, 0) AS samples
                      FROM buckets b
                      LEFT JOIN per_bucket pb    ON pb.bucket = b.bucket
                      LEFT JOIN sample_counts sc ON sc.bucket = b.bucket
                )
                INSERT INTO structs.stat_rollup (bucket, metric, object_type, sum, population, samples, source)
                SELECT r.bucket, %3$L, %4$L::structs.object_type,
                       COALESCE(r.total, 0), r.population, r.samples, 'backfill'
                  FROM rolled r
                 WHERE r.population > 0
                ON CONFLICT (metric, object_type, bucket) DO NOTHING
            $q$, m.stat_table, v_typefilter, m.metric, v_type)
            USING v_from, p_to;

            GET DIAGNOSTICS v_rows = ROW_COUNT;
            v_total := v_total + v_rows;
        END LOOP;

        RETURN v_total;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.stat_rollup_backfill(TEXT, TIMESTAMPTZ, TIMESTAMPTZ) IS
        'Fill structs.stat_rollup for one metric over [p_from, p_to) from the stat_* samples using last-observation-carried-forward per object (the webapp StatReadManager computation). Never overwrites existing rows.';

    GRANT SELECT ON structs.stat_rollup, structs.stat_rollup_metric TO structs_webapp;
    GRANT SELECT ON structs.stat_rollup, structs.stat_rollup_metric TO structs_indexer;

    SELECT cron.schedule(
        'stat_rollup_snapshot',
        '2 * * * *',
        'SELECT structs.stat_rollup_snapshot();'
    );

COMMIT;

-- History, one metric per transaction.
SELECT format('SELECT %L AS metric, structs.stat_rollup_backfill(%L) AS rows;', metric, metric)
  FROM structs.stat_rollup_metric
 ORDER BY metric
\gexec

-- And the hour that just closed, so the series is current from the first read.
SELECT structs.stat_rollup_snapshot();
