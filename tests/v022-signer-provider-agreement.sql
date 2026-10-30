-- Disposable database only. Exercise installed wrappers and actual queue rows.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.substation(id,owner) VALUES('4-990940','1-990940');
DO $$
DECLARE
    request signer.tx%ROWTYPE;
    bad NUMERIC;
    invalid_mask INTEGER;
BEGIN
    IF signer.UINT64_ARGUMENT(9007199254740993.0,'quantity') <> '9007199254740993'
        OR signer.UINT64_ARGUMENT(18446744073709551615,'quantity') <> '18446744073709551615'
        OR signer.COIN_ARGUMENT(9007199254740993.0,'ualpha') <> '9007199254740993ualpha'
        OR signer.PENALTY_ARGUMENT(0.1000000000000000000) <> '0.1' THEN
        RAISE EXCEPTION 'exact CLI serialization lost value or retained invalid decimal scale';
    END IF;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,1.1,18446744073709551616,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.UINT64_ARGUMENT(bad,'quantity');
            RAISE EXCEPTION 'invalid uint64 accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,1.1,0.0000000000000000001,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.PENALTY_ARGUMENT(bad);
            RAISE EXCEPTION 'invalid penalty accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        PERFORM signer.COIN_ARGUMENT(1,'ua lpha');
        RAISE EXCEPTION 'invalid coin denomination accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    PERFORM signer.tx_provider_create('1-990940','4-990940','ualpha',0,'openMarket',0.1,0.2,
        0,18446744073709551615,0,9007199254740993);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id <> '1-990940' OR request.flags <> '{"owner-id":"1-990940"}'
        OR request.args <> '["4-990940","0ualpha","openMarket","0.1","0.2","0","18446744073709551615","0","9007199254740993"]'
        OR request.permission_requirement<>256 THEN
        RAISE EXCEPTION 'personal provider wrapper changed actor, owner, source bit or argv';
    END IF;
    UPDATE structs.permission SET val=256 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'source-allocation-only key could not create provider';
    END IF;
    UPDATE structs.permission SET val=262144 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'provider-open key substituted for source-allocation authority';
    END IF;
    UPDATE structs.permission SET val=256 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_provider_create('1-990940','4-990940','ualpha',1,'guildMarket',0,1,1,10,1,10,'0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.flags <> '{"owner-id":"0-990940"}'
        OR (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>2
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'guild-owned provider skipped independent guild authority';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('0-990940@1-990940','0-990940','1-990940',272);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'explicitly authorized guild-owned provider refused';
    END IF;

    PERFORM signer.tx_agreement_open('1-990940','10-990940',9007199254740993,1);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args <> '["10-990940","9007199254740993","1"]'
        OR request.flags <> '{"owner-id":"1-990940"}'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'personal open-market contract lost exact args or unnecessarily required provider-open bit';
    END IF;
    PERFORM signer.tx_agreement_open('1-990940','10-990940',10,1,'0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.flags <> '{"owner-id":"0-990940"}'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'guild collateral owner was not preserved';
    END IF;
    UPDATE structs.permission SET val=256 WHERE id='0-990940@1-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'request kept collateral authority after its revocation';
    END IF;
    BEGIN
        PERFORM signer.tx_agreement_open('1-990940','10-990940',0,1);
        RAISE EXCEPTION 'zero agreement duration accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    PERFORM signer.tx_agreement_duration_increase('1-990940','11-990940',9007199254740993);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args <> '["11-990940","9007199254740993"]'
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=request.id
            AND check_type='object-owner' AND object_id='11-990940' AND permission=16)
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=request.id
            AND check_type='object' AND object_id='11-990940' AND permission=4) THEN
        RAISE EXCEPTION 'extension lost agreement-update or owner-spend check';
    END IF;
    PERFORM signer.tx_provider_withdraw_balance('1-990940','10-990940',NULL);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args <> '["10-990940",""]' THEN RAISE EXCEPTION 'default withdrawal was redirected to a signing address'; END IF;
    PERFORM signer.tx_provider_withdraw_balance('1-990940','10-990940','explicitrecipient');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args <> '["10-990940","explicitrecipient"]' THEN RAISE EXCEPTION 'explicit withdrawal destination changed'; END IF;

    PERFORM signer.tx_provider_update_capacity_minimum('1-990940','10-990940',9007199254740993);
    PERFORM signer.tx_provider_update_capacity_maximum('1-990940','10-990940',18446744073709551615);
    PERFORM signer.tx_provider_update_duration_minimum('1-990940','10-990940',0);
    PERFORM signer.tx_provider_update_duration_maximum('1-990940','10-990940',18446744073709551615);
    PERFORM signer.tx_provider_update_access_policy('1-990940','10-990940','closedMarket');
    PERFORM signer.tx_provider_delete('1-990940','10-990940');
    PERFORM signer.tx_agreement_capacity_increase('1-990940','11-990940',9007199254740993);
    PERFORM signer.tx_agreement_capacity_decrease('1-990940','11-990940',1);
    PERFORM signer.tx_agreement_close('1-990940','11-990940');
    IF EXISTS (SELECT 1 FROM signer.tx WHERE requested_player_id IS DISTINCT FROM '1-990940'
        OR contract IS DISTINCT FROM 'v022-1')
        OR EXISTS (SELECT 1 FROM signer.tx t CROSS JOIN LATERAL jsonb_array_elements(t.args) a
                   WHERE jsonb_typeof(a)<>'string') THEN
        RAISE EXCEPTION 'a provider/agreement wrapper bypassed actor or exact-argument contracts';
    END IF;
END $$;
ROLLBACK;
