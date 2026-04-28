-- Verify structs-pg:cache-trigger-add-queue-20260427-ugc-fields on pg

BEGIN;

    SELECT 'cache.handle_event_player(jsonb)'::regprocedure;
    SELECT 'cache.handle_event_guild(jsonb)'::regprocedure;
    SELECT 'cache.handle_event_substation(jsonb)'::regprocedure;
    SELECT 'cache.handle_event_planet(jsonb)'::regprocedure;

ROLLBACK;
