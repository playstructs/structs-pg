-- Verify structs-pg:role-structs-webapp-20261030-struct-state on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT object_id,attribute_type,val FROM structs.struct_attribute LIMIT 0;
SELECT defending_struct_id,protected_struct_id FROM structs.struct_defender LIMIT 0;
SELECT name,value FROM structs.setting LIMIT 0;
SELECT height FROM structs.current_block LIMIT 0;
ROLLBACK;
