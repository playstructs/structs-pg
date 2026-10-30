-- Revert structs-pg:role-structs-webapp-20261030-struct-state from pg
BEGIN;
REVOKE SELECT ON structs.struct_attribute,structs.struct_defender,
    structs.setting,structs.current_block FROM structs_webapp;
COMMIT;
