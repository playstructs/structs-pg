-- Verify structs-pg:table-sync-state-20261030-economy-contract on pg
BEGIN;
SELECT chain_id,contract,activation_height,last_height,last_block_hash,updated_at
FROM sync_state.economy_contract WHERE FALSE;
SELECT 1 / (has_table_privilege('structs_indexer','sync_state.economy_contract','SELECT,INSERT,UPDATE'))::int;
-- Inspect direct ACLs: some existing deployments made service roles
-- superusers. This migration does not change their cluster-wide attributes.
SELECT 1 / (NOT EXISTS(SELECT 1 FROM pg_class c,
    LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
    WHERE c.oid='sync_state.economy_contract'::regclass
      AND a.grantee IN (0,'structs_webapp'::regrole::oid)
      AND a.privilege_type IN ('INSERT','UPDATE','DELETE')))::int;
SELECT 1 / (position('sync_state.economy_contract' IN pg_get_functiondef('structs.api_readiness(text[])'::regprocedure))>0)::int;
SELECT * FROM structs.api_readiness(ARRAY[]::TEXT[]);
ROLLBACK;
