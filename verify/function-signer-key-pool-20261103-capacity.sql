BEGIN;
SELECT 1 / (prosecdef AND proconfig @> ARRAY['search_path=pg_catalog, pg_temp'])::int
FROM pg_proc WHERE oid='signer.request_account_v022(integer,numeric,integer,uuid,text)'::regprocedure;
SELECT 1 / has_function_privilege('structs_tsa',
    'signer.request_account_v022(integer,numeric,integer,uuid,text)','EXECUTE')::int;
ROLLBACK;
