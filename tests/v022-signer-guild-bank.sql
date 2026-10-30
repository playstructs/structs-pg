-- Disposable PostgreSQL only; no chain transaction is broadcast.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql

CREATE FUNCTION pg_temp.bank_refuses(statement TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement;
    EXCEPTION WHEN invalid_parameter_value THEN RETURN; END;
    RAISE EXCEPTION 'invalid guild-bank input accepted: %',statement;
END $$;

DO $$
DECLARE request signer.tx%ROWTYPE; claimed JSONB; target TEXT := 'structs1' || repeat('q',38);
BEGIN
    INSERT INTO structs.guild(id,owner) VALUES('0-990941','1-990940');
    PERFORM signer.tx_guild_bank_mint('1-990940',9007199254740993,18446744073709551615,'0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id<>'1-990940' OR request.contract<>'v022-1'
        OR request.args<>'["9007199254740993","18446744073709551615"]'::jsonb
        OR request.flags<>'{"guild-id":"0-990940"}'::jsonb
        OR (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>3 THEN
        RAISE EXCEPTION 'mint lost actor, exact amount or independent authority';
    END IF;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'player token-transfer authority granted access to somebody else''s treasury';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
        VALUES('0-990940@1-990940','0-990940','1-990940',8192);
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'mint authority alone allowed guild treasury spending';
    END IF;
    -- Each permission is separate on chain: a direct mint grant and a complete
    -- rank-derived transfer grant satisfy their respective checks independently.
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
        VALUES('0-990940','0-990940',16,10);
    UPDATE structs.permission SET val=8192 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'guild permissions bypassed the signing key''s transfer ceiling';
    END IF;
    UPDATE structs.permission SET val=8208 WHERE id='8-queuekeya@0';
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed->'transaction'->>'id' IS DISTINCT FROM request.id::text
        OR claimed->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'independent valid guild mint/transfer grants did not claim the intended actor';
    END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(request.id,(claimed->'transaction'->>'claim_token')::uuid,'fixture completed');

    DELETE FROM structs.permission WHERE id='0-990940@1-990940';
    DELETE FROM structs.permission_guild_rank WHERE object_id='0-990940';
    UPDATE structs.player SET guild_id='' WHERE id='1-990941';
    PERFORM signer.tx_guild_bank_mint('1-990941',1,1,'0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeyb') THEN
        RAISE EXCEPTION 'guild owner who is not a member cannot mint';
    END IF;
    UPDATE structs.guild SET owner='1-990940' WHERE id='0-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'changed guild owner retained the previous owner''s spend authority';
    END IF;
    UPDATE signer.tx SET status='error' WHERE status='pending';
    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_guild_bank_mint('1-990940',1,1,'');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    UPDATE structs.player SET guild_id='0-990941' WHERE id='1-990940';
    IF request.flags<>'{"guild-id":"0-990940"}'::jsonb THEN
        RAISE EXCEPTION 'default guild was not captured explicitly at enqueue';
    END IF;
    PERFORM signer.tx_guild_bank_confiscate_and_burn('1-990940',18446744073709551615,target,'0-990941');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>jsonb_build_array('18446744073709551615',target)
        OR (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>1
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=request.id AND object_id='0-990941' AND permission=4096) THEN
        RAISE EXCEPTION 'confiscation changed its exact subject or demanded unrelated asset-transfer permission';
    END IF;
    UPDATE structs.permission SET val=4096 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'burn-only owner key cannot confiscate';
    END IF;
    UPDATE signer.tx SET status='error' WHERE status='pending';

    PERFORM signer.tx_guild_bank_convert('1-990940','0-990940',18446744073709551615,9007199254740993);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["0-990940","18446744073709551615","9007199254740993"]'::jsonb
        OR request.requested_player_id<>'1-990940' OR request.flags<>'{}'::jsonb
        OR (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>1
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'conversion did not use only the requested player''s transfer authority';
    END IF;
    PERFORM signer.tx_guild_bank_redeem('1-990940',9007199254740993,'uguild.0-990940',18446744073709551615);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["9007199254740993uguild.0-990940","18446744073709551615"]'::jsonb THEN
        RAISE EXCEPTION 'redemption denomination or exact base-unit amount changed';
    END IF;
    PERFORM signer.tx_guild_bank_convert_token('1-990940',9007199254740993,'uguild.0-990940','0-990941',1);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["9007199254740993uguild.0-990940","0-990941","1"]'::jsonb THEN
        RAISE EXCEPTION 'cross-guild conversion has wrong exact CLI positionals';
    END IF;

    UPDATE signer.tx SET status='error' WHERE status='pending';
    UPDATE structs.guild SET owner='1-990941' WHERE id='0-990940';
    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_guild_update_bank_convert_in_fee('1-990940','0-990940','0.999999999999999999');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id<>'1-990940' OR request.args<>'["0-990940","0.999999999999999999"]'::jsonb
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'fee update silently selected the guild owner instead of its requested actor';
    END IF;
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank) VALUES('0-990940','0-990941',2,10);
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN RAISE EXCEPTION 'rank granted administration'; END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',2);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'direct administration did not authorize the intended actor';
    END IF;
    PERFORM signer.tx_guild_update_bank_convert_out_fee('1-990940','0-990940','0.000000000000000000');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["0-990940","0"]'::jsonb THEN RAISE EXCEPTION 'zero fee was not exact'; END IF;
END $$;

DO $$
DECLARE value NUMERIC; denom TEXT; fee TEXT;
BEGIN
    FOREACH value IN ARRAY ARRAY[NULL::numeric,0,-1,0.5,18446744073709551616,'NaN'::numeric,'Infinity'::numeric] LOOP
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_mint(''1-990940'',%L,1,''0-990940'')',value));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_mint(''1-990940'',1,%L,''0-990940'')',value));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_redeem(''1-990940'',%L,''uguild.0-990940'',1)',value));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_redeem(''1-990940'',1,''uguild.0-990940'',%L)',value));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_convert(''1-990940'',''0-990940'',%L,1)',value));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_convert_token(''1-990940'',1,''uguild.0-990940'',''0-990941'',%L)',value));
    END LOOP;
    FOREACH denom IN ARRAY ARRAY[NULL,'guild.0-990940','UGUILD.0-990940','ualpha','alpha','factory/issuer/token','uguild.0-0990940','uguild.0-999999','uguild.0-990940.extra'] LOOP
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_bank_redeem(''1-990940'',1,%L,1)',denom));
    END LOOP;
    FOREACH fee IN ARRAY ARRAY[NULL,'','1','1.0','-0.1','NaN','Infinity','1e-3','0.0000000000000000001',' 0.5'] LOOP
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_update_bank_convert_in_fee(''1-990940'',''0-990940'',%L)',fee));
        PERFORM pg_temp.bank_refuses(format('SELECT signer.tx_guild_update_bank_convert_out_fee(''1-990940'',''0-990940'',%L)',fee));
    END LOOP;
    PERFORM pg_temp.bank_refuses('SELECT signer.tx_guild_bank_convert_token(''1-990940'',1,''uguild.0-990940'',''0-990940'',1)');
    PERFORM pg_temp.bank_refuses('SELECT signer.tx_guild_bank_convert(''1-990940'',''0-999999'',1,1)');
    PERFORM pg_temp.bank_refuses('SELECT signer.tx_guild_bank_confiscate_and_burn(''1-990940'',1,''not-an-address'',''0-990940'')');
END $$;

-- Existing SECURITY DEFINER wrappers remain callable by a scoped client. They
-- preserve the requested actor without granting the generic queue primitive.
CREATE ROLE v022_bank_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer TO v022_bank_caller;
SET LOCAL ROLE v022_bank_caller;
SELECT signer.tx_guild_bank_convert('1-990940','0-990940',1,1);
RESET ROLE;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command='guild-bank-convert'
        AND args='["0-990940","1","1"]'::jsonb AND requested_player_id='1-990940') THEN
        RAISE EXCEPTION 'scoped caller could not enqueue the existing wrapper';
    END IF;
END $$;
ROLLBACK;
