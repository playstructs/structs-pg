-- Deploy structs-pg:role-structs-webapp-20260914-timeouts to pg
--
-- Request-path sessions should never hold the database indefinitely. The
-- webapp role had no statement_timeout and no
-- idle_in_transaction_session_timeout, so a hung request or an abandoned
-- transaction could pin a snapshot (blocking vacuum) or a lock (blocking
-- sync-state) forever. Every sampled webapp statement completes in well under
-- a second; 60 s is generous headroom. Settings take effect for new sessions.

BEGIN;

    ALTER ROLE structs_webapp SET statement_timeout = '60s';
    ALTER ROLE structs_webapp SET idle_in_transaction_session_timeout = '5min';

COMMIT;
