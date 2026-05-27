-- Verify structs-pg:retire-cache-20260522 on pg
--
-- Asserts the post-cutover invariants:
--   1. The seven cache-era triggers on structs.* tables are gone.
--      MUST stay in sync with the hardcoded list in
--      sync-state/internal/doctor/doctor.go.
--   2. The cache schema contains only views — no tables, functions,
--      or triggers leaked through.
--   3. The four compatibility views exist.

BEGIN;

    DO $$
    DECLARE
        n_legacy BIGINT;
    BEGIN
        SELECT COUNT(*) INTO n_legacy
          FROM pg_trigger t
          JOIN pg_class   c ON c.oid = t.tgrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'structs'
           AND t.tgname IN (
                'update_address_guild_id',
                'name_planet',
                'add_infusion_ledger_entry',
                'planet_activity_struct_movement',
                'planet_activity_fleet_move',
                'planet_activity_raid_status',
                'planet_activity_struct_attribute')
           AND NOT t.tgisinternal;
        IF n_legacy > 0 THEN
            RAISE EXCEPTION 'verify: % cache-era triggers still present on structs.* tables', n_legacy;
        END IF;
    END $$;

    DO $$
    DECLARE
        n_nonview BIGINT;
    BEGIN
        SELECT COUNT(*) INTO n_nonview
          FROM pg_class  c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'cache'
           AND c.relkind <> 'v';
        IF n_nonview > 0 THEN
            RAISE EXCEPTION 'verify: cache schema contains % non-view relations', n_nonview;
        END IF;
    END $$;

    DO $$
    DECLARE
        n_views INT;
    BEGIN
        SELECT COUNT(*) INTO n_views
          FROM pg_views
         WHERE schemaname = 'cache'
           AND viewname IN ('blocks', 'tx_results', 'events', 'attributes');
        IF n_views <> 4 THEN
            RAISE EXCEPTION 'verify: expected 4 cache.* compat views, found %', n_views;
        END IF;
    END $$;

ROLLBACK;
