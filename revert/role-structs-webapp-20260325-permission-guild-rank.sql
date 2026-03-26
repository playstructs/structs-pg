-- Revert structs-pg:role-structs-webapp-20260325-permission-guild-rank from pg

BEGIN;

    REVOKE ALL ON structs.permission_guild_rank FROM structs_webapp;

COMMIT;
