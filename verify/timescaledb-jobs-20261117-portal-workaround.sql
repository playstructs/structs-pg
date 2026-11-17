-- Verify structs-pg:timescaledb-jobs-20261117-portal-workaround on pg
BEGIN;
DO $body$
BEGIN
    IF (SELECT count(*) FROM structs.timescale_portal_workaround) <> 5 THEN
        RAISE EXCEPTION 'Expected five policy snapshots';
    END IF;
    IF EXISTS (
        SELECT 1 FROM structs.timescale_portal_workaround s
        LEFT JOIN timescaledb_information.jobs j ON j.job_id=s.job_id
        LEFT JOIN cron.job c ON c.jobid=s.cron_job_id
        WHERE j.job_id IS NULL OR j.scheduled
           OR (s.cron_job_id IS NULL AND (s.native_scheduled OR s.cron_preexisting))
           OR (s.cron_job_id IS NOT NULL AND
               (c.jobid IS NULL OR NOT c.active OR c.schedule<>s.cron_schedule
                OR c.command<>s.cron_command OR c.username<>s.job_owner
                OR c.database<>current_database()
                OR c.jobname<>'timescale-portal-workaround-'||s.job_id))
    ) THEN
        RAISE EXCEPTION 'Timescale portal workaround configuration mismatch';
    END IF;
END
$body$;
ROLLBACK;
