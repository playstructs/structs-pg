-- Deploy structs-pg:grid-cap-handler-permissions-20261114 to pg
BEGIN;
-- The retired cache schema remains visible to the webapp. This compatibility
-- handler is SECURITY DEFINER and may only be called by its database owner.
REVOKE ALL ON FUNCTION cache.handle_event_grid(jsonb) FROM PUBLIC, structs_webapp;
COMMIT;
