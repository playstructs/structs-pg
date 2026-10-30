-- Disposable database only. Queue isolation and all fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql

DO $$
DECLARE
    request JSONB;
    claimed JSONB;
    tx_id INTEGER;
    before_count BIGINT;
    invalid_checks JSONB;
BEGIN
    SELECT count(*) INTO before_count FROM signer.account;
    request := signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse',
        '["validator","9007199254740993ualpha"]','{"owner-id":"1-990940"}',
        '[{"check_type":"object","object_id":"1-990940","permission":32}]');
    tx_id := (request->>'id')::int;
    IF request->'args'->>1 <> '9007199254740993ualpha' OR request->>'requested_player_id'<>'1-990940'
        OR request->>'chain_id'<>'structstestnet-111' OR request->>'prepared_height'<>'3353000' THEN
        RAISE EXCEPTION 'queue lost exact args, actor or protocol context';
    END IF;
    IF signer.CLAIM_INTERNAL_TRANSACTION()->>'id' IS NOT NULL
        OR signer.CLAIM_INTERNAL_ACCOUNT(tx_id)::jsonb->>'id' IS NOT NULL THEN
        RAISE EXCEPTION 'legacy worker consumed a versioned request';
    END IF;
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'transaction'->>'id' <> tx_id::text
        OR claimed->'account'->>'address'<>'queuekeya'
        OR claimed->'transaction'->>'account_id'<>'990940'
        OR claimed->'transaction'->>'claim_token' IS NULL
        OR (SELECT status FROM signer.account WHERE id=990940)<>'signing' THEN
        RAISE EXCEPTION 'atomic claim did not reserve the requested player''s authorized key';
    END IF;
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'claimed transaction was handed out twice';
    END IF;
    request := signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{}',
        '[{"check_type":"object","object_id":"1-990940","permission":32}]');
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL
        OR (SELECT status FROM signer.tx WHERE id=(request->>'id')::int)<>'pending'
        OR (SELECT count(*) FROM signer.account)<>before_count THEN
        RAISE EXCEPTION 'busy key triggered another identity, a new key or premature claim';
    END IF;
    UPDATE signer.account SET status='available' WHERE id=990940;
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'permission revoked after enqueue was ignored';
    END IF;
    UPDATE signer.tx SET status='error' WHERE status='pending';

    request := signer.CREATE_TRANSACTION_V022('1-990940','10-990940','structs','agreement-open',
        '["10-990940","100","10"]','{"owner-id":"1-990940"}',
        '[{"check_type":"provider-open","object_id":"10-990940","permission":262144},
          {"check_type":"object","object_id":"1-990940","permission":16}]');
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'account'->>'address'<>'queuerestricted' THEN
        RAISE EXCEPTION 'open-market access incorrectly demanded provider-open on the spending key';
    END IF;
    UPDATE signer.account SET status='available' WHERE id IN (990940,990942);
    request := signer.CREATE_TRANSACTION_V022('1-990940','10-990940','structs','agreement-open','[]','{}',
        '[{"check_type":"provider-open","object_id":"10-990940","permission":262144},
          {"check_type":"object","object_id":"1-990940","permission":16}]');
    UPDATE structs.provider SET access_policy='closedMarket' WHERE id='10-990940';
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'changed provider policy was ignored';
    END IF;
    UPDATE signer.tx SET status='error' WHERE status='pending';

    UPDATE structs.permission SET val=20 WHERE id='8-queuekeya@0';
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('11-990940@1-990940','11-990940','1-990940',4);
    request := signer.CREATE_TRANSACTION_V022('1-990940','11-990940','structs','agreement-duration-increase','[]','{}',
        '[{"check_type":"object","object_id":"11-990940","permission":4},
          {"check_type":"object-owner","object_id":"11-990940","permission":16}]');
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'agreement update permission spent guild collateral';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('0-990940@1-990940','0-990940','1-990940',16);
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'separately authorized agreement extension was not claimable';
    END IF;
    BEGIN
        PERFORM signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[9007199254740993]','{}',
            '[{"check_type":"object","object_id":"1-990940","permission":32}]');
        RAISE EXCEPTION 'numeric JSON arg accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{"from":"otherkey"}',
            '[{"check_type":"object","object_id":"1-990940","permission":32}]');
        RAISE EXCEPTION 'worker identity override accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    FOREACH invalid_checks IN ARRAY ARRAY['null','[]','[{}]',
        '[{"check_type":"object","object_id":"1-990940","permission":null}]',
        '[{"check_type":"object","object_id":"1-990940","permission":1.5}]']::JSONB[] LOOP
        BEGIN
            PERFORM signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{}',invalid_checks);
            RAISE EXCEPTION 'invalid authority checks accepted: %',invalid_checks;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        INSERT INTO signer.tx(module,command,requested_player_id,chain_id,prepared_height)
        VALUES('structs','reactor-infuse','1-990940','structstestnet-111',3353000);
        RAISE EXCEPTION 'partial version context accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- Incomplete indexing must stop both enqueue and claim, even for existing keys.
UPDATE sync_state.sync_cursor SET status='catching_up';
DO $$ BEGIN
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN RAISE EXCEPTION 'claim bypassed readiness'; END IF;
    BEGIN
        PERFORM signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{}',
            '[{"check_type":"object","object_id":"1-990940","permission":32}]');
        RAISE EXCEPTION 'enqueue bypassed readiness';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
UPDATE sync_state.sync_cursor SET status='current';
UPDATE signer.account SET status='available' WHERE id=990940;
UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';

CREATE ROLE v022_signer_queue_fixture NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_signer_queue_fixture;
GRANT SELECT ON signer.role,structs.player,structs.player_address,structs.permission,
    structs.permission_guild_rank,structs.vault,structs.guild TO v022_signer_queue_fixture;
GRANT SELECT,INSERT,UPDATE ON signer.tx TO v022_signer_queue_fixture;
GRANT SELECT,INSERT ON signer.tx_authority TO v022_signer_queue_fixture;
GRANT SELECT,UPDATE ON signer.account TO v022_signer_queue_fixture;
GRANT USAGE ON SEQUENCE signer.tx_id_seq TO v022_signer_queue_fixture;
GRANT EXECUTE ON FUNCTION structs.api_readiness(TEXT[]),signer.CLAIM_TRANSACTION_V022(),
    signer.CREATE_TRANSACTION_V022(CHARACTER VARYING,CHARACTER VARYING,structs.signer_tx_module,
        structs.signer_tx_type,JSONB,JSONB,JSONB) TO v022_signer_queue_fixture;
SET LOCAL ROLE v022_signer_queue_fixture;
DO $$
DECLARE request JSONB; claimed JSONB;
BEGIN
    request := signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{}',
        '[{"check_type":"object","object_id":"1-990940","permission":32}]');
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'transaction'->>'id' <> request->>'id'
        OR claimed->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'non-superuser queue/claim failed';
    END IF;
END $$;
ROLLBACK;
