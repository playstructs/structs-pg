-- Deploy structs-pg:timescaledb-jobs-20261117-portal-workaround to pg
-- PostgreSQL 18.7 portal validation breaks Timescale policy background runners.
-- https://github.com/timescale/timescaledb/issues/11038
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE TABLE structs.timescale_portal_workaround (
    job_id integer PRIMARY KEY,
    native_scheduled boolean NOT NULL,
    cron_job_id bigint,
    cron_preexisting boolean NOT NULL,
    cron_schedule text NOT NULL,
    cron_command text NOT NULL,
    job_owner name NOT NULL
);
REVOKE ALL ON structs.timescale_portal_workaround FROM PUBLIC;
DO $body$
DECLARE
    target record;
    policy record;
    existing record;
    extension_schema name;
    command text;
    cron_id bigint;
    adopted boolean;
BEGIN
    SELECT n.nspname INTO STRICT extension_schema
    FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
    WHERE e.extname='timescaledb';
    FOR target IN SELECT * FROM (VALUES
        ('policy_refresh_continuous_aggregate','planet_activity_hourly','10 minutes'::interval,'*/10 * * * *'),
        ('policy_refresh_continuous_aggregate','planet_activity_daily','1 hour'::interval,'3 * * * *'),
        ('policy_refresh_continuous_aggregate','planet_activity_player_daily','1 hour'::interval,'5 * * * *'),
        ('policy_compression','planet_activity','12 hours'::interval,'15 0,12 * * *'),
        ('policy_job_stat_history_retention',NULL,'6 hours'::interval,'20 */6 * * *')
    ) AS targets(proc_name,relation_name,expected_interval,schedule)
    LOOP
        -- IDs vary with installation order. Fail atomically on missing/duplicate policies.
        SELECT j.* INTO STRICT policy FROM timescaledb_information.jobs j
        WHERE j.proc_schema='_timescaledb_functions' AND j.proc_name=target.proc_name
          AND (target.relation_name IS NULL OR
               (j.hypertable_schema='structs' AND j.hypertable_name=target.relation_name));
        IF policy.schedule_interval <> target.expected_interval THEN
            RAISE EXCEPTION 'Custom interval for Timescale job %; adapt migration before deploying',policy.job_id;
        END IF;
        IF EXISTS (SELECT 1 FROM timescaledb_information.job_stats
                   WHERE job_id=policy.job_id AND job_status='Running') THEN
            RAISE EXCEPTION 'Timescale job % is running; retry when idle',policy.job_id;
        END IF;
        command := format('CALL %I.run_job(%s);',extension_schema,policy.job_id);
        SELECT * INTO existing FROM cron.job
        WHERE jobname='timescale-portal-workaround-'||policy.job_id;
        adopted := FOUND;
        cron_id := NULL;
        IF adopted THEN
            -- Adopt the incident workaround without duplicating it or changing ownership.
            IF existing.command <> command OR existing.schedule <> target.schedule
               OR existing.database <> current_database()
               OR existing.username <> policy.owner::text OR NOT existing.active THEN
                RAISE EXCEPTION 'Conflicting cron job %; inspect before deploying',existing.jobid;
            END IF;
            cron_id := existing.jobid;
        ELSIF policy.scheduled THEN
            cron_id := cron.schedule_in_database(
                'timescale-portal-workaround-'||policy.job_id,
                target.schedule,command,current_database(),policy.owner::text);
        END IF;
        INSERT INTO structs.timescale_portal_workaround VALUES
            (policy.job_id,policy.scheduled,cron_id,adopted,target.schedule,command,policy.owner::text);
        EXECUTE format('SELECT %I.alter_job($1, scheduled => false)',extension_schema)
            USING policy.job_id;
    END LOOP;
END
$body$;
COMMENT ON TABLE structs.timescale_portal_workaround IS
    'Rollback state for Timescale portal workaround. Monitor executions in cron.job_run_details; foreground run_job does not update native job_stats.';
COMMIT;
