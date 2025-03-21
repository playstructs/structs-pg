-- Deploy structs-pg:role-structs-crawler to pg

BEGIN;

    GRANT CONNECT ON DATABASE structs TO structs_crawler;
    ALTER ROLE structs_crawler SET search_path TO cache, public, structs;

    GRANT USAGE on SCHEMA structs TO structs_crawler;
    GRANT SELECT ON structs.guild TO structs_crawler;
    GRANT SELECT ON structs.guild_meta TO structs_crawler;
    GRANT EXECUTE ON FUNCTION structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB) TO structs_crawler;

COMMIT;
