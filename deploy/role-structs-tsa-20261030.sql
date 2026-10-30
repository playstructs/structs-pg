-- Deploy structs-pg:role-structs-tsa-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'TSA worker privileges require the coordinated v022-1 contract'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='structs_tsa') THEN
        CREATE ROLE structs_tsa LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='structs_tsa' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication)) THEN
        RAISE EXCEPTION 'TSA worker database role must not have administrative privileges'; END IF;
END $$;
CREATE TABLE signer.worker_function_settings (
    identity TEXT PRIMARY KEY,
    security_definer BOOLEAN NOT NULL,
    configuration TEXT[],
    privileges ACLITEM[]
);
REVOKE ALL ON TABLE signer.worker_function_settings FROM PUBLIC;
INSERT INTO signer.worker_function_settings
SELECT p.oid::regprocedure::text,p.prosecdef,p.proconfig,p.proacl
FROM (VALUES ('signer.claim_transaction_v022(uuid)'),('signer.submission_v022(integer)'),('signer.save_signed_transaction_v022(integer,uuid,bytea,numeric,numeric,numeric,numeric)'),('signer.begin_submission_v022(integer,uuid)'),('signer.mark_submission_unknown_v022(integer,uuid,text)'),('signer.record_submission_result_v022(integer,uuid,jsonb)'),('signer.abort_unsent_transaction_v022(integer,uuid,text)'),('signer.claim_account_v022()'),('signer.account_request_v022(integer)'),('signer.update_pending_account(integer,character varying,character varying,character varying,character varying,numeric,jsonb,character varying)'),('signer.account_registration_ready_v022(integer,integer)'),('signer.activate_account_v022(integer,integer)'),('signer.registration_failed_v022(integer)'),('signer.renew_account_registration_v022(integer,integer,character varying,jsonb)'),('signer.request_account_v022(integer,numeric,integer,uuid,text)'),('signer.request_pool_account_v022(uuid,integer,integer,integer,numeric,integer,uuid,jsonb)'),('signer.sync_local_keys_v022(uuid,jsonb)'),('signer.reconcile_local_key_v022(uuid,character varying,text,bigint,bigint,character varying,numeric,boolean)'),('signer.prepare_role_key_v022(integer,integer)'),('signer.bind_role_key_v022(integer,uuid,character varying,character varying,character varying)'),('signer.activate_role_key_v022(integer,uuid,character varying,bigint,bigint)')) names(identity) JOIN pg_proc p ON p.oid=names.identity::regprocedure;
DO $$ DECLARE f RECORD; BEGIN
    FOR f IN SELECT identity FROM signer.worker_function_settings LOOP
        EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER',f.identity::regprocedure);
        EXECUTE format('ALTER FUNCTION %s SET search_path=pg_catalog,pg_temp',f.identity::regprocedure);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO structs_tsa',f.identity::regprocedure);
    END LOOP;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO structs_tsa',current_database());
END $$;

CREATE FUNCTION signer.WORKER_AUTHORIZED_ACCOUNTS_V022(_tx_id INTEGER)
RETURNS TABLE(account_id INTEGER,address VARCHAR,status structs.signer_account_status)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
    SELECT * FROM signer.AUTHORIZED_ACCOUNTS_V022(_tx_id);
$BODY$;
CREATE FUNCTION signer.BIND_REQUEST_ACCOUNT_V022(_account_id INTEGER,_address VARCHAR) RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _account signer.account%ROWTYPE;
BEGIN
    IF _address IS NULL OR _address !~ '^structs1[ac-hj-np-z02-9]{38}$' THEN
        RAISE EXCEPTION 'invalid requested key address' USING ERRCODE='22023'; END IF;
    UPDATE signer.account SET address=_address,updated_at=NOW()
    WHERE id=_account_id AND status='generating' AND (address IS NULL OR address=_address)
        AND EXISTS (SELECT 1 FROM signer.account_request WHERE account_id=_account_id)
    RETURNING * INTO _account;
    IF NOT FOUND THEN RAISE EXCEPTION 'key request is no longer generating this address' USING ERRCODE='55000'; END IF;
    RETURN to_jsonb(_account);
END
$BODY$;
CREATE FUNCTION signer.INVALIDATE_LOCAL_KEY_V022(_inventory_id UUID,_address VARCHAR) RETURNS VOID
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
    UPDATE signer.local_key SET state='unverified' WHERE inventory_id=_inventory_id AND address=_address;
$BODY$;
REVOKE ALL ON FUNCTION signer.WORKER_AUTHORIZED_ACCOUNTS_V022(INTEGER),
    signer.BIND_REQUEST_ACCOUNT_V022(INTEGER,VARCHAR),signer.INVALIDATE_LOCAL_KEY_V022(UUID,VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION signer.WORKER_AUTHORIZED_ACCOUNTS_V022(INTEGER),
    signer.BIND_REQUEST_ACCOUNT_V022(INTEGER,VARCHAR),signer.INVALIDATE_LOCAL_KEY_V022(UUID,VARCHAR),
    structs.api_readiness(TEXT[]) TO structs_tsa;
GRANT USAGE ON SCHEMA signer,structs TO structs_tsa;
GRANT SELECT ON signer.tx,signer.account,signer.role,signer.tx_submission,signer.account_request,
    signer.local_key,signer.role_key_request TO structs_tsa;
GRANT SELECT(id,val) ON structs.permission TO structs_tsa;
GRANT SELECT(role_id) ON structs.player_internal_pending TO structs_tsa;
-- The worker has no direct mutation grants on game projections, accounts,
-- requests or submissions. Its writes go through the guarded APIs above.
COMMIT;
