BEGIN;
SELECT 1 / (prosecdef AND proconfig @> ARRAY['search_path=pg_catalog, pg_temp'])::int
FROM pg_proc WHERE oid='signer.claim_transaction_v022(uuid)'::regprocedure;
SELECT 1 / has_function_privilege('structs_tsa','signer.claim_transaction_v022(uuid)','EXECUTE')::int;
SELECT 1 / (NOT prosecdef)::int FROM pg_proc
WHERE oid='signer.claim_transaction_v022()'::regprocedure;
ROLLBACK;
