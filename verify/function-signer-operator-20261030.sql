-- Verify structs-pg:function-signer-operator-20261030 on pg
BEGIN;
SELECT request_id,role_id,username,guild_id,permissions FROM signer.role_operator_request WHERE FALSE;
SELECT 1/has_function_privilege('structs_tsa','signer.request_role_v022(character varying,character varying,integer,uuid)','EXECUTE')::int;
ROLLBACK;
