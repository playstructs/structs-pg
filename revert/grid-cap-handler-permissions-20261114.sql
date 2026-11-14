-- Revert structs-pg:grid-cap-handler-permissions-20261114 from pg
BEGIN;
-- Deliberately retain the restriction on revert. Removing a migration marker
-- must not grant the webapp or PUBLIC permission to mutate indexed state.
REVOKE ALL ON FUNCTION cache.handle_event_grid(jsonb) FROM PUBLIC, structs_webapp;
COMMIT;
