-- Verify structs-pg:role-structs-webapp-20261030-catalog on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT id,owner,rate_amount,rate_denom FROM structs.provider LIMIT 0;
SELECT id,owner,provider_id,capacity,end_block FROM structs.agreement LIMIT 0;
ROLLBACK;
