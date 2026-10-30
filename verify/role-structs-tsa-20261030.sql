-- Verify structs-pg:role-structs-tsa-20261030 on pg
BEGIN;
SELECT 1/(count(*)=21)::int FROM signer.worker_function_settings;
SELECT 1/(NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication)::int FROM pg_roles WHERE rolname='structs_tsa';
SELECT 1/has_function_privilege('structs_tsa','signer.claim_transaction_v022(uuid)','EXECUTE')::int;
SELECT 1/(NOT has_table_privilege('structs_tsa','signer.account','UPDATE') AND NOT has_table_privilege('structs_tsa','structs.player','UPDATE'))::int;
SET LOCAL ROLE structs_tsa;
SELECT signer.SUBMISSION_V022(-1);
SELECT * FROM signer.WORKER_AUTHORIZED_ACCOUNTS_V022(-1);
SELECT * FROM structs.api_readiness(ARRAY[]::TEXT[]);
ROLLBACK;
