-- Revert structs-pg:timescaledb-jobs-20261117-portal-workaround from pg
-- Quiesce workaround cron jobs before reverting; see docs/timescaledb-jobs.md.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $body$
DECLARE v_state record; extension_schema name;
BEGIN
    SELECT n.nspname INTO STRICT extension_schema
    FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='timescaledb';
    IF EXISTS (
        SELECT 1 FROM cron.job_run_details r
        JOIN structs.timescale_portal_workaround s ON s.cron_job_id=r.jobid
        WHERE r.status IN ('starting','running')
    ) THEN
        RAISE EXCEPTION 'Workaround job is running; wait for completion before reverting';
    END IF;
    FOR v_state IN SELECT * FROM structs.timescale_portal_workaround LOOP
        IF v_state.cron_job_id IS NOT NULL THEN
            IF NOT EXISTS (SELECT 1 FROM cron.job c WHERE c.jobid=v_state.cron_job_id
                AND c.command=v_state.cron_command AND c.username=v_state.job_owner
                AND c.database=current_database()
                AND c.jobname='timescale-portal-workaround-'||v_state.job_id) THEN
                RAISE EXCEPTION 'Cron job % changed; inspect before reverting',v_state.cron_job_id;
            END IF;
            IF v_state.cron_preexisting THEN
                -- Restore adopted incident jobs after the operator quiesced them.
                PERFORM cron.alter_job(v_state.cron_job_id,schedule=>v_state.cron_schedule,active=>true);
            ELSE
                PERFORM cron.unschedule(v_state.cron_job_id);
            END IF;
        END IF;
        EXECUTE format('SELECT %I.alter_job($1, scheduled => $2)',extension_schema)
            USING v_state.job_id,v_state.native_scheduled;
    END LOOP;
END
$body$;
DROP TABLE structs.timescale_portal_workaround;
COMMIT;
