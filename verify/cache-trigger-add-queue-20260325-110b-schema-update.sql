-- Verify structs-pg:cache-trigger-add-queue-20260325-110b-schema-update on pg

BEGIN;

    SELECT has_function_privilege('cache.handle_event_guild_rank_permission(jsonb)', 'execute');

    SELECT 1 FROM cache.event_handlers
    WHERE composite_key = 'structs.structs.EventGuildRankPermission.guildRankPermissionRecord';

ROLLBACK;
