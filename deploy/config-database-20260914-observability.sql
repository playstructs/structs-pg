-- Deploy structs-pg:config-database-20260914-observability to pg
--
-- Database-scoped observability settings. These are the settings that can be
-- managed from sqitch (ALTER DATABASE ... SET is transactional; ALTER SYSTEM
-- is not and shared_preload_libraries needs a restart anyway; those live in
-- the container image). They apply to new sessions in this database.
--
--   track_io_timing            real read/write timings in pg_stat_io,
--                              pg_stat_database and EXPLAIN (ANALYZE, BUFFERS)
--   log_temp_files = 0         log every work_mem spill with the statement;
--                              the database has spilled 965 GB to date with
--                              no record of which statements did it
--   log_min_duration_statement statements over 1 s go to the log with text
--
-- Uses current_database() so the change is valid on any target.

BEGIN;

    DO $$
    BEGIN
        EXECUTE format('ALTER DATABASE %I SET track_io_timing = on', current_database());
        EXECUTE format('ALTER DATABASE %I SET log_temp_files = 0', current_database());
        EXECUTE format('ALTER DATABASE %I SET log_min_duration_statement = %L', current_database(), '1s');
    END
    $$;

COMMIT;
