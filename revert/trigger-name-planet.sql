-- Revert structs-pg:trigger-name-planet from pg

BEGIN;

DROP FUNCTION structs.NAME_PLANET();

COMMIT;
