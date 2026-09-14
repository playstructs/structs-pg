-- Revert structs-pg:function-planet-activity-20260915-players from pg

BEGIN;

    DROP FUNCTION IF EXISTS structs.planet_activity_players(structs.grass_category, CHARACTER VARYING, JSONB);
    DROP FUNCTION IF EXISTS structs.object_owner(CHARACTER VARYING);

COMMIT;
