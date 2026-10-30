-- Disposable database only. The chain remains authoritative for balances,
-- validator state and inclusion; these tests exercise installed SQL and claims.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.reactor(id,validator) VALUES('3-990940','structsvaloper1source');
UPDATE structs.guild SET primary_reactor_id='3-990940' WHERE id='0-990940';
INSERT INTO structs.struct(id,owner,is_destroyed) VALUES('5-990940','1-990941',FALSE);
INSERT INTO structs.substation(id,owner) VALUES('4-990940','1-990941');
DO $$
DECLARE request signer.tx%ROWTYPE; bad NUMERIC; destination TEXT;
BEGIN
    -- No vault row yet: owner-routed infusion may provision it on chain.
    PERFORM signer.tx_infuse('1-990940','0-990940',0.000001,'alpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["structsvaloper1source","1ualpha"]' OR request.command<>'reactor-infuse'
        OR request.module<>'structs' OR request.flags<>'{"owner-id":"1-990940"}'
        OR request.permission_requirement<>32 OR request.requested_player_id<>'1-990940' THEN
        RAISE EXCEPTION 'default infusion did not preserve actor, vault routing or exact amount';
    END IF;
    INSERT INTO structs.vault(owner_id,address,account_number) VALUES
        ('1-990940','walletvaulta',0),('1-990941','walletvaultb',1),('0-990940','walletguild',2);
    FOREACH destination IN ARRAY ARRAY['0-990940','3-990940','structsvaloper1source'] LOOP
        PERFORM signer.tx_infuse('1-990940','queuekeya',destination,9007199254740993,'ualpha');
        SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
        IF request.args<>'["structsvaloper1source","9007199254740993ualpha"]'
            OR request.flags<>'{"delegator-address":"queuekeya"}' THEN
            RAISE EXCEPTION 'retained-address reactor infusion kept obsolete positional delegator';
        END IF;
    END LOOP;
    PERFORM signer.tx_reactor_defuse('1-990940',NULL,'structsvaloper1source',1,'alpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["structsvaloper1source","1000000ualpha"]'
        OR request.flags<>'{"owner-id":"1-990940"}' OR request.permission_requirement<>128 THEN
        RAISE EXCEPTION 'vault defuse contract mismatch';
    END IF;
    PERFORM signer.tx_reactor_begin_migration('1-990940','queuekeya','structsvaloper1source','structsvaloper1destination',1,'ualpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["structsvaloper1source","structsvaloper1destination","1ualpha"]'
        OR request.flags<>'{"delegator-address":"queuekeya"}' OR request.permission_requirement<>64 THEN
        RAISE EXCEPTION 'reactor migration contract mismatch';
    END IF;
    PERFORM signer.tx_reactor_cancel_defusion('1-990940','queuekeya','structsvaloper1source',1,'ualpha',3353000);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["structsvaloper1source","1ualpha","3353000"]' OR request.permission_requirement<>32 THEN
        RAISE EXCEPTION 'cancel-defusion requires infusion authority and new positional arguments';
    END IF;
    UPDATE structs.permission SET val=128 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'defuse-only key was selected for cancel-defusion';
    END IF;
    UPDATE structs.permission SET val=32 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'infuse-only key could not cancel defusion';
    END IF;
    PERFORM signer.tx_reactor_cancel_defusion('1-990940',NULL,'structsvaloper1source',1,'ualpha',9007199254740993);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args->>2<>'9007199254740993' THEN RAISE EXCEPTION 'creation height lost precision'; END IF;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,0,1.1,9223372036854775808,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_reactor_cancel_defusion('1-990940',NULL,'structsvaloper1source',1,'ualpha',bad);
            RAISE EXCEPTION 'invalid creation height accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        PERFORM signer.tx_reactor_cancel_defusion('1-990940',NULL,'structsvaloper1source',1,'ualpha',NULL);
        RAISE EXCEPTION 'untyped NULL height accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    -- Independent asset authority: do not replace the requested actor with a
    -- guild owner's key, or use the actor's personal permission for its vault.
    PERFORM signer.tx_infuse('1-990940',NULL,'3-990940',1,'ualpha','0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.flags<>'{"owner-id":"0-990940"}'
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'guild vault source did not require separate authority';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('0-990940@1-990940','0-990940','1-990940',240);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'authorized guild-vault infusion refused';
    END IF;
    PERFORM signer.tx_reactor_defuse('1-990940','walletguild','structsvaloper1source',1,'ualpha','0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.flags<>'{"owner-id":"0-990940"}' THEN RAISE EXCEPTION 'matching vault owner route changed'; END IF;
    PERFORM signer.tx_reactor_begin_migration('1-990940',NULL,'structsvaloper1source','structsvaloper1destination',1,'ualpha','0-990940');
    PERFORM signer.tx_reactor_cancel_defusion('1-990940',NULL,'structsvaloper1source',1,'ualpha',9223372036854775807,'0-990940');
    BEGIN
        PERFORM signer.tx_infuse('1-990940','queuekeya','3-990940',1,'ualpha','0-990940');
        RAISE EXCEPTION 'mismatched owner and delegator accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_reactor_defuse('1-990940','queuerestricted','structsvaloper1source',1,'ualpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    UPDATE structs.player_address SET status='revoked' WHERE address='queuerestricted';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'revoked subject address retained authority';
    END IF;
    UPDATE structs.player_address SET status='approved',player_id='1-990941' WHERE address='queuerestricted';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'reassigned subject was authorized by its old owner';
    END IF;
    UPDATE structs.player_address SET player_id='1-990940' WHERE address='queuerestricted';

    -- A generator's owner may differ; funding always belongs to this actor.
    PERFORM signer.tx_infuse('1-990940','5-990940',18446744073709551615,'ualpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.command<>'struct-generator-infuse' OR request.flags<>'{}'
        OR request.args<>'["5-990940","18446744073709551615ualpha"]'
        OR request.permission_requirement<>32 THEN RAISE EXCEPTION 'generator contract mismatch'; END IF;
    PERFORM signer.tx_infuse('1-990940','walletvaulta','5-990940',1,'ualpha','1-990940');
    BEGIN
        PERFORM signer.tx_infuse('1-990940','queuekeya','5-990940',1,'ualpha');
        RAISE EXCEPTION 'generator silently ignored a retained source';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_infuse('1-990940',NULL,'5-990940',1,'ualpha','0-990940');
        RAISE EXCEPTION 'generator silently ignored a guild owner';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_infuse('1-990940','5-990940',18446744073709551616,'ualpha');
        RAISE EXCEPTION 'overflow generator fuel accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    UPDATE structs.struct SET is_destroyed=TRUE WHERE id='5-990940';
    BEGIN
        PERFORM signer.tx_infuse('1-990940','5-990940',1,'ualpha');
        RAISE EXCEPTION 'destroyed generator accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    FOREACH destination IN ARRAY ARRAY[NULL,'','unknown','0-990949','3-990949','5-990949'] LOOP
        BEGIN
            PERFORM signer.tx_infuse('1-990940',destination,1,'ualpha');
            RAISE EXCEPTION 'missing infusion destination silently accepted: %',destination;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,0,0.1,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_infuse('1-990940','3-990940',bad,'ualpha');
            RAISE EXCEPTION 'invalid base-unit amount accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        PERFORM signer.tx_infuse('1-990940','3-990940',1,'uguild.0-990940');
        RAISE EXCEPTION 'non-Alpha reactor fuel accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_infuse('1-990940','3-990940',0.0000001,'alpha');
        RAISE EXCEPTION 'fractional micro-Alpha accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    PERFORM signer.tx_bank_send('1-990940',0.000001,'alpha','1-990941');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["walletvaulta","walletvaultb","1ualpha"]'
        OR request.module<>'structs' OR request.command<>'player-send' OR request.permission_requirement<>16 THEN
        RAISE EXCEPTION 'player-to-player transfer did not use both vaults and PlayerSend';
    END IF;
    PERFORM signer.tx_player_send('1-990940',NULL,'literalrecipient',9007199254740993,'factory/issuer/token');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["walletvaulta","literalrecipient","9007199254740993factory/issuer/token"]' THEN
        RAISE EXCEPTION 'literal recipient, denomination or amount was rewritten';
    END IF;
    PERFORM signer.tx_player_send('1-990940','queuekeya','literalrecipient',1,'ualpha');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args->>0<>'queuekeya' THEN RAISE EXCEPTION 'explicit retained transfer source changed'; END IF;
    PERFORM signer.tx_player_send('1-990940','walletguild','literalrecipient',1,'uguild.0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'authorized guild transfer refused';
    END IF;
    DELETE FROM structs.permission WHERE id='0-990940@1-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'guild transfer ignored revoked guild grant';
    END IF;
    DELETE FROM structs.vault WHERE owner_id='1-990941';
    BEGIN
        PERFORM signer.tx_bank_send('1-990940',1,'ualpha','1-990941');
        RAISE EXCEPTION 'missing recipient vault fell back to its primary address';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;

    PERFORM signer.tx_guild_create('1-990940','3-990940','https://guild.example',NULL);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    UPDATE structs.permission SET val=17 WHERE id='8-queuekeya@0';
    IF request.permission_requirement<>17 OR request.args<>'["3-990940","https://guild.example",""]'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'paid guild creation requires play plus transfer, not reactor ownership';
    END IF;
    UPDATE structs.permission SET val=524288 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'obsolete reactor-charter permission authorized paid guild creation';
    END IF;
    UPDATE structs.permission SET val=1041 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_guild_create('1-990940','3-990940','','4-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'guild creation bypassed entry substation connection authority';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('4-990940@1-990940','4-990940','1-990940',1024);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'authorized paid guild creation refused';
    END IF;
    BEGIN
        PERFORM signer.tx_guild_create_charter('1-990940','3-990940','',NULL,NULL,NULL);
        RAISE EXCEPTION 'empty legacy charter silently became a paid transaction';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_guild_create_charter('1-990940','3-990940','',NULL,'legacy-proof','nonce');
        RAISE EXCEPTION 'legacy charter silently became a paid transaction';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract IS DISTINCT FROM 'v022-1'
        OR requested_player_id<>'1-990940'
        OR EXISTS (SELECT 1 FROM jsonb_array_elements(args) a WHERE jsonb_typeof(a)<>'string')) THEN
        RAISE EXCEPTION 'wallet wrappers lost actor, contract or exact JSON string arguments';
    END IF;
END $$;

-- Same callable boundary as existing application clients: no direct queue or
-- chain-table access is needed for the SECURITY DEFINER wrapper.
CREATE ROLE v022_wallet_caller;
GRANT USAGE ON SCHEMA signer TO v022_wallet_caller;
GRANT EXECUTE ON FUNCTION signer.tx_infuse(character varying,character varying,numeric,character varying) TO v022_wallet_caller;
SET LOCAL ROLE v022_wallet_caller;
SELECT signer.tx_infuse('1-990940','3-990940',1,'ualpha');
RESET ROLE;
ROLLBACK;
