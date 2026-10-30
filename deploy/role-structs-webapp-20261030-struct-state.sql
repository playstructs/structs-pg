-- Deploy structs-pg:role-structs-webapp-20261030-struct-state to pg
BEGIN;
-- Existing struct list/detail reads need status, defenders and sweep boundaries.
-- Keep these reads available to the application role without broad schema grants.
GRANT SELECT ON structs.struct_attribute,structs.struct_defender,
    structs.setting,structs.current_block TO structs_webapp;
COMMIT;
