-- Deploy structs-pg:role-structs-webapp to pg

BEGIN;

    GRANT CONNECT ON DATABASE structs TO structs_webapp;
    ALTER ROLE structs_webapp SET search_path TO cache, public, structs;

    GRANT USAGE on SCHEMA cache TO structs_webapp;
    GRANT SELECT ON cache.events TO structs_webapp;
    GRANT SELECT ON cache.blocks TO structs_webapp;
    GRANT SELECT ON cache.tx_results TO structs_webapp;
    GRANT SELECT ON cache.attributes TO structs_webapp;
    GRANT SELECT, DELETE ON cache.queue TO structs_webapp;

    GRANT USAGE ON SCHEMA structs TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.allocation TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.guild TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.infusion TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.planet TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.player TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.reactor TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.struct TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.struct_type TO structs_webapp;
    GRANT SELECT, INSERT, UPDATE, DELETE ON structs.substation TO structs_webapp;

COMMIT;
