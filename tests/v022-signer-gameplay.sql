-- Disposable PostgreSQL only; all fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.struct(id,owner,is_destroyed) VALUES('5-990940','1-990941',FALSE),('5-990941','1-990940',FALSE);
INSERT INTO structs.fleet(id,owner) VALUES('9-990940','1-990941');
INSERT INTO structs.planet(id,owner) VALUES('2-990940','1-990941');
INSERT INTO structs.reactor(id,owner,validator) VALUES('3-990940','1-990941','structsvaloper1'||repeat('q',32)||'3u5j96');
CREATE FUNCTION pg_temp.gameplay_last() RETURNS INTEGER LANGUAGE sql AS $$ SELECT max(id) FROM signer.tx $$;
CREATE FUNCTION pg_temp.gameplay_eligible(_id INTEGER,_address VARCHAR,_expected BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_id) WHERE address=_address) IS DISTINCT FROM _expected THEN
        RAISE EXCEPTION 'gameplay % eligibility for % should be %',_id,_address,_expected;
    END IF;
END $$;
CREATE FUNCTION pg_temp.gameplay_refuses(statement TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement; EXCEPTION WHEN invalid_parameter_value OR feature_not_supported THEN RETURN; END;
    RAISE EXCEPTION 'invalid gameplay input accepted: %',statement;
END $$;

SAVEPOINT ownership;
DO $$ DECLARE request_id INTEGER; BEGIN
    -- Playing a struct is authorized on its owner, never merely on that struct.
    PERFORM signer.tx_struct_activate('1-990940','5-990940');
    request_id:=pg_temp.gameplay_last();
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeyb',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('5-990940@1-990940','5-990940','1-990940',1);
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('1-990941@1-990940','1-990941','1-990940',1);
    UPDATE structs.permission SET val=1 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.struct SET is_destroyed=TRUE WHERE id='5-990940';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.struct SET is_destroyed=FALSE,owner='1-990940' WHERE id='5-990940';
    DELETE FROM structs.permission WHERE id='1-990941@1-990940';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    PERFORM signer.tx_fleet_move('1-990940','9-990940','2-990940');
    request_id:=pg_temp.gameplay_last(); PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.fleet SET owner='1-990940' WHERE id='9-990940';
    UPDATE structs.permission SET val=1 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
END $$;
ROLLBACK TO ownership; RELEASE ownership;

SAVEPOINT proofs;
DO $$ DECLARE request_id INTEGER; entry RECORD; BEGIN
    FOR entry IN SELECT * FROM (VALUES ('build_complete',1048576),('ore_mine_complete',2097152),('ore_refine_complete',4194304)) v(command,permission) LOOP
        UPDATE structs.permission SET val=entry.permission WHERE id='8-queuekeya@0';
        EXECUTE format('SELECT signer.tx_struct_%s(''1-990940'',''5-990940'',''exact-proof'',''184467440737095516150000'')',entry.command);
        request_id:=pg_temp.gameplay_last();
        PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
        INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('1-990941@1-990940','1-990941','1-990940',entry.permission);
        PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
        IF (SELECT args->>2 FROM signer.tx WHERE id=request_id)<>'184467440737095516150000' THEN RAISE EXCEPTION 'opaque nonce changed'; END IF;
        UPDATE structs.permission SET val=1 WHERE id='8-queuekeya@0';
        PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
        DELETE FROM structs.permission WHERE id='1-990941@1-990940';
    END LOOP;
    PERFORM signer.tx_planet_raid_complete('1-990940','9-990940','proof','nonce with spaces');
    request_id:=pg_temp.gameplay_last(); PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=8388608 WHERE id='8-queuekeya@0';
    UPDATE structs.fleet SET owner='1-990940' WHERE id='9-990940';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
END $$;
ROLLBACK TO proofs; RELEASE proofs;

SAVEPOINT restart;
DO $$ DECLARE request_id INTEGER; claim JSONB; BEGIN
    -- Registration is sufficient; no Play bit, reactor ownership or permission row is required.
    DELETE FROM structs.permission WHERE id='8-queuekeya@0';
    UPDATE signer.account SET status='signing' WHERE id=990942;
    PERFORM signer.tx_reactor_restart('1-990940','structsvaloper1'||repeat('q',32)||'3u5j96');
    request_id:=pg_temp.gameplay_last();
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',TRUE);
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeyb',FALSE);
    DELETE FROM structs.reactor WHERE id='3-990940';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.reactor(id,validator) VALUES('3-990940','structsvaloper1'||repeat('q',32)||'3u5j96');
    UPDATE structs.player_address SET status='revoked' WHERE address='queuekeya';
    PERFORM pg_temp.gameplay_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.player_address SET status='approved' WHERE address='queuekeya';
    claim:=signer.CLAIM_TRANSACTION_V022();
    IF claim->'transaction'->>'id' IS DISTINCT FROM request_id::text OR claim->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'permissionless restart changed actor or required an invented bit';
    END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(request_id,(claim->'transaction'->>'claim_token')::uuid,'fixture completed');
END $$;
ROLLBACK TO restart; RELEASE restart;

DO $$ DECLARE request_id INTEGER; BEGIN
    PERFORM signer.tx_struct_build_initiate('1-990940',18446744073709551615,'land',18446744073709551615);
    request_id:=pg_temp.gameplay_last();
    IF (SELECT args FROM signer.tx WHERE id=request_id)<>'["1-990940","18446744073709551615","land","18446744073709551615"]'::jsonb THEN RAISE EXCEPTION 'inexact type or slot'; END IF;
    PERFORM signer.tx_struct_move('1-990940','5-990941','fleet','space',18446744073709551615);
    IF (SELECT args->>3 FROM signer.tx WHERE id=pg_temp.gameplay_last())<>'18446744073709551615' THEN RAISE EXCEPTION 'inexact move slot'; END IF;
    PERFORM signer.tx_struct_attack('1-990940','5-990941','5-990940,5-990940','primaryWeapon');
    IF (SELECT args->>1 FROM signer.tx WHERE id=pg_temp.gameplay_last())<>'5-990940,5-990940' THEN RAISE EXCEPTION 'target multiplicity lost'; END IF;
    PERFORM signer.tx_struct_build_cancel('1-990940','5-990941');
    PERFORM pg_temp.gameplay_eligible(pg_temp.gameplay_last(),'queuekeya',TRUE);
END $$;
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_player_resume('1-990940')$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_build_initiate('1-990940',1.1,'land',0)$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_build_initiate('1-990940',1,'land',-1)$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_build_initiate('1-990940',1,'planet',0)$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_move('1-990940','5-990941','reactor','space',0)$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_move('1-990940','5-990941','planet','land',18446744073709551616)$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_attack('1-990940','5-990941','5-990940,,5-990940','primaryWeapon')$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_attack('1-990940','5-990941','5-990940','primary')$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_struct_defense_set('1-990940','5-990941','5-990941')$$);
SELECT pg_temp.gameplay_refuses($$SELECT signer.tx_reactor_restart('1-990940','3-990940')$$);

CREATE ROLE v022_gameplay_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_gameplay_caller;
GRANT SELECT ON signer.tx,signer.tx_authority,signer.role,signer.account,structs.player,structs.player_address,
    structs.permission,structs.permission_guild_rank,structs.guild,structs.struct,structs.vault TO v022_gameplay_caller;
SET LOCAL ROLE v022_gameplay_caller;
SELECT signer.tx_struct_activate('1-990940','5-990941');
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(pg_temp.gameplay_last()) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'scoped gameplay caller could not prepare/read eligibility';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
