BEGIN;
SELECT 1 / (count(*)=2)::int FROM pg_proc
WHERE oid IN ('signer.save_signed_transaction_v022(integer,uuid,bytea,numeric,numeric,numeric,numeric)'::regprocedure,
    'signer.reconcile_local_key_v022(uuid,character varying,text,bigint,bigint,character varying,numeric,boolean)'::regprocedure)
AND prosecdef AND proconfig @> ARRAY['search_path=pg_catalog, pg_temp']
AND has_function_privilege('structs_tsa',oid,'EXECUTE');
ROLLBACK;
