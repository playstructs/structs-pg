-- Disposable PostgreSQL only. All requests, roles and fixture changes roll back.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.guild(id,owner,join_infusion_minimum_p,join_infusion_minimum_bypass_by_invite,
    join_infusion_minimum_bypass_by_request,primary_reactor_id,entry_substation_id)
VALUES('0-990941','1-990943',0,'member','member','3-990941','');
UPDATE structs.guild SET join_infusion_minimum_p=0,join_infusion_minimum_bypass_by_invite='permissioned',
    join_infusion_minimum_bypass_by_request='permissioned',primary_reactor_id='3-990940',entry_substation_id=''
WHERE id='0-990940';
INSERT INTO structs.player(id,primary_address,guild_id,guild_rank) VALUES
    ('1-990943','membershipkeyc','0-990941',20),('1-990944','membershipkeyd','0-990941',20);
INSERT INTO structs.permission(id,object_type,object_index,object_id,player_id,val)
VALUES('8-membershipkeyc@0','address','membershipkeyc','1-990943','1-990943',33554431);
INSERT INTO signer.role(id,player_id,status) VALUES(990943,'1-990943','ready');
INSERT INTO signer.account(id,role_id,address,status) VALUES(990943,990943,'membershipkeyc','available');
INSERT INTO structs.reactor(id,validator,guild_id) VALUES
    ('3-990940','validator-a','0-990940'),('3-990941','validator-b','0-990941'),('3-990942','validator-c','0-990940');
INSERT INTO structs.substation(id,owner,deletion_pending) VALUES
    ('4-990940','1-990940',FALSE),('4-990941','1-990941',FALSE);

CREATE FUNCTION pg_temp.last_membership() RETURNS INTEGER LANGUAGE sql AS $$
    SELECT max(id) FROM signer.tx WHERE command::text LIKE 'guild-membership-%';
$$;
CREATE FUNCTION pg_temp.member_eligible(_id INTEGER,_address VARCHAR,_expected BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_id) WHERE address=_address) IS DISTINCT FROM _expected THEN
        RAISE EXCEPTION 'membership % eligibility for % should be %',_id,_address,_expected;
    END IF;
END $$;
CREATE FUNCTION pg_temp.membership_refuses(statement TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement;
    EXCEPTION WHEN invalid_parameter_value THEN RETURN; END;
    RAISE EXCEPTION 'invalid membership input accepted: %',statement;
END $$;

SAVEPOINT policies;
DO $$
DECLARE request_id INTEGER;
BEGIN
    PERFORM signer.tx_guild_membership_invite('1-990940','0-990940','1-990943','');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    PERFORM pg_temp.member_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='member' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=512 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='closed' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='unknown-policy' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='permissioned' WHERE id='0-990940';
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',512);
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player SET guild_id='' WHERE id='1-990941';
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='member' WHERE id='0-990940';
    PERFORM signer.tx_guild_membership_invite('1-990941','0-990940','1-990943','');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'queuekeyb',TRUE);
    UPDATE structs.guild SET owner='1-990940' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'queuekeyb',FALSE);
END $$;
ROLLBACK TO policies;
RELEASE policies;

SAVEPOINT consent;
DO $$
DECLARE request_id INTEGER;
BEGIN
    PERFORM signer.tx_guild_membership_invite_approve('1-990943','0-990940','1-990943','');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    INSERT INTO structs.guild_membership_application(guild_id,player_id,join_type,status,substation_id)
        VALUES('0-990940','1-990943','invite','approved','');
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.guild_membership_application SET status='proposed',join_type='request';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.guild_membership_application SET join_type='invite';
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='closed' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    PERFORM signer.tx_guild_membership_invite_deny('1-990943','0-990940','1-990943');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',TRUE);
    PERFORM signer.tx_guild_membership_invite_approve('1-990940','0-990940','1-990943','');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('1-990943@1-990940','1-990943','1-990940',512);
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player_address SET status='revoked' WHERE address='queuekeya';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.player_address SET status='approved' WHERE address='queuekeya';
    UPDATE structs.player SET guild_id='0-990940' WHERE id='1-990943';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
END $$;
ROLLBACK TO consent;
RELEASE consent;

SAVEPOINT requests;
DO $$
DECLARE request_id INTEGER;
BEGIN
    PERFORM signer.tx_guild_membership_request('1-990943','0-990940','');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',TRUE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_request='closed' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',FALSE);
    INSERT INTO structs.guild_membership_application(guild_id,player_id,join_type,status)
        VALUES('0-990940','1-990943','request','proposed');
    PERFORM signer.tx_guild_membership_request_revoke('1-990943','0-990940','1-990943');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',TRUE);
    PERFORM signer.tx_guild_membership_request_approve('1-990940','0-990940','1-990943','');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_request='member' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=512 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_guild_membership_request_deny('1-990940','0-990940','1-990943');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'queuekeya',TRUE);
    UPDATE structs.guild SET join_infusion_minimum_bypass_by_request='permissioned' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',512);
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.guild_membership_application SET join_type='invite';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    PERFORM signer.tx_guild_membership_invite_revoke('1-990940','0-990940','1-990943');
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'queuekeya',TRUE);
END $$;
ROLLBACK TO requests;
RELEASE requests;

SAVEPOINT kicking;
DO $$
DECLARE request_id INTEGER;
BEGIN
    UPDATE structs.player SET guild_id='0-990940',guild_rank=20 WHERE id='1-990943';
    PERFORM signer.tx_guild_membership_kick('1-990940','0-990940','1-990943');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',512);
    UPDATE structs.permission SET val=512 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player SET guild_rank=10 WHERE id='1-990943';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.player SET guild_id='0-990941',guild_rank=18446744073709551615 WHERE id='1-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.guild SET owner='1-990943' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'queuekeya',FALSE);
END $$;
ROLLBACK TO kicking;
RELEASE kicking;

SAVEPOINT stations;
DO $$
DECLARE request_id INTEGER;
BEGIN
    INSERT INTO structs.guild_membership_application(guild_id,player_id,join_type,status,substation_id)
        VALUES('0-990940','1-990943','invite','proposed','4-990941');
    UPDATE structs.permission SET val=512 WHERE id='8-membershipkeyc@0';
    PERFORM signer.tx_guild_membership_invite_approve('1-990943','0-990940','1-990943','4-990941');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990941';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.substation SET deletion_pending=FALSE WHERE id='4-990941';
    PERFORM signer.tx_guild_membership_invite_approve('1-990943','0-990940','1-990943','4-990940');
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('4-990940@1-990943','4-990940','1-990943',1024);
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.permission SET val=1536 WHERE id='8-membershipkeyc@0';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990941';
    -- Approval validates its new override. Direct join also validates the old
    -- destination before the handler applies the override.
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.guild_membership_application SET join_type='direct';
    PERFORM signer.tx_guild_membership_join('1-990943','0-990940','4-990940',ARRAY[]::varchar[]);
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',FALSE);
    UPDATE structs.substation SET deletion_pending=FALSE WHERE id='4-990941';
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',TRUE);
END $$;
ROLLBACK TO stations;
RELEASE stations;

SAVEPOINT joins;
DO $$
DECLARE request_id INTEGER; vault_address TEXT := 'structs1'||repeat('q',38); claim JSONB;
BEGIN
    INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990943',vault_address,0);
    INSERT INTO structs.infusion(destination_id,address,destination_type,player_id,owner_id,fuel_p,power_p)
        VALUES('3-990941',vault_address,'reactor','1-990943','1-990943',1,1);
    UPDATE structs.permission SET val=512 WHERE id='8-membershipkeyc@0';
    PERFORM signer.tx_guild_membership_join('1-990943','0-990940','',ARRAY[('3-990941-'||vault_address)::varchar]);
    request_id := pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.guild SET join_infusion_minimum_p=1 WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.permission SET val=576 WHERE id='8-membershipkeyc@0';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.permission SET val=512 WHERE id='8-membershipkeyc@0';
    UPDATE structs.guild SET primary_reactor_id='3-990941' WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.guild SET primary_reactor_id='3-990940' WHERE id='0-990940';
    UPDATE structs.reactor SET guild_id='0-990940' WHERE id='3-990941';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',TRUE);
    UPDATE structs.vault SET owner_id='1-990944' WHERE address=vault_address;
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.vault SET owner_id='1-990943' WHERE address=vault_address;
    UPDATE structs.infusion SET player_id='1-990944' WHERE address=vault_address;
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
    UPDATE structs.infusion SET player_id='1-990943' WHERE address=vault_address;
    claim := signer.CLAIM_TRANSACTION_V022();
    IF claim->'transaction'->>'id' IS DISTINCT FROM request_id::text OR claim->'account'->>'address'<>'membershipkeyc' THEN
        RAISE EXCEPTION 'direct join did not atomically claim the intended eligible key';
    END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(request_id,(claim->'transaction'->>'claim_token')::uuid,'fixture completed');
    UPDATE structs.guild SET join_infusion_minimum_p=NULL WHERE id='0-990940';
    PERFORM pg_temp.member_eligible(request_id,'membershipkeyc',FALSE);
END $$;
ROLLBACK TO joins;
RELEASE joins;

DO $$
DECLARE address TEXT := 'structs1'||repeat('q',38); flag TEXT; statement TEXT;
BEGIN
    PERFORM pg_temp.membership_refuses('SELECT signer.tx_guild_membership_invite(''1-990940'',''0-990940'',''1-999999'','''')');
    PERFORM pg_temp.membership_refuses('SELECT signer.tx_guild_membership_join(''1-990943'',''0-990940'','''',ARRAY[NULL]::varchar[])');
    PERFORM pg_temp.membership_refuses('SELECT signer.tx_guild_membership_join(''1-990943'',''0-990940'','''',ARRAY[''not-an-infusion'']::varchar[])');
    PERFORM pg_temp.membership_refuses(format('SELECT signer.tx_guild_membership_join(''1-990943'',''0-990940'','''',ARRAY[%L,%L]::varchar[])','3-990941-'||address,'3-990941-'||address));
    FOREACH flag IN ARRAY ARRAY['from','chain-id','unordered','timeout-duration','aux','ledger','tip','dry-run'] LOOP
        statement := format('SELECT signer.CREATE_TRANSACTION_V022(''1-990940'',''1-990940'',''structs'',''reactor-infuse'',''[]'',%L,''[{"check_type":"object","object_id":"1-990940","permission":32}]'')',jsonb_build_object(flag,'true'));
        PERFORM pg_temp.membership_refuses(statement);
    END LOOP;
    -- Hand-written malformed queue rows fail closed rather than invent consent.
    PERFORM signer.tx_guild_membership_request('1-990943','0-990940','');
    UPDATE signer.tx SET args='["0-990940","extra"]' WHERE id=pg_temp.last_membership();
    PERFORM pg_temp.member_eligible(pg_temp.last_membership(),'membershipkeyc',FALSE);
END $$;

CREATE ROLE v022_membership_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_membership_caller;
GRANT SELECT ON signer.tx,signer.tx_authority,signer.role,signer.account,structs.player,structs.player_address,
    structs.permission,structs.permission_guild_rank,structs.guild,structs.guild_membership_application,
    structs.substation,structs.reactor,structs.infusion,structs.asset_owner,structs.vault TO v022_membership_caller;
SET LOCAL ROLE v022_membership_caller;
SELECT signer.tx_guild_membership_request('1-990943','0-990940','');
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(pg_temp.last_membership()) WHERE address='membershipkeyc') THEN
        RAISE EXCEPTION 'scoped membership caller could not prepare/read eligibility';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
