-- Deploy structs-pg:role-structs-webapp-20260325-permission-guild-rank to pg

BEGIN;

    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.permission_guild_rank TO structs_webapp;

COMMIT;
