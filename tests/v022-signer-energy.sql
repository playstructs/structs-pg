-- Disposable PostgreSQL only. All requests, roles and fixture changes roll back.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.player(id,primary_address,guild_id,guild_rank) VALUES('1-990943','energykeyc','',20);
INSERT INTO structs.substation(id,owner,deletion_pending) VALUES
    ('4-990940','1-990940',FALSE),('4-990941','1-990941',FALSE),('4-990942','0-990940',FALSE);
INSERT INTO structs.reactor(id,owner,validator) VALUES('3-990940','0-990940','energy-validator');
INSERT INTO structs.allocation(id,source_id,controller,allocation_type,destination_id) VALUES
    ('6-990940','1-990940','1-990941','dynamic','4-990941'),
    ('6-990941','3-990940','0-990940','static','4-990940');
UPDATE structs.player SET substation_id='4-990941' WHERE id='1-990943';
CREATE FUNCTION pg_temp.energy_eligible(_id INTEGER,_address VARCHAR,_expected BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_id) WHERE address=_address) IS DISTINCT FROM _expected THEN
        RAISE EXCEPTION 'energy % eligibility for % should be %',_id,_address,_expected;
    END IF;
END $$;
CREATE FUNCTION pg_temp.energy_last() RETURNS INTEGER LANGUAGE sql AS $$ SELECT max(id) FROM signer.tx $$;
CREATE FUNCTION pg_temp.energy_refuses(statement TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement; EXCEPTION WHEN invalid_parameter_value THEN RETURN; END;
    RAISE EXCEPTION 'invalid energy input accepted: %',statement;
END $$;

SAVEPOINT allocation;
DO $$ DECLARE request_id INTEGER; BEGIN
    -- Update checks the source, not Update on the controller or allocation.
    UPDATE structs.permission SET val=256 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_allocation_update('1-990940','6-990940',18446744073709551615);
    request_id:=pg_temp.energy_last();
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    IF (SELECT args FROM signer.tx WHERE id=request_id)<>'["6-990940","18446744073709551615"]'::jsonb THEN RAISE EXCEPTION 'inexact power'; END IF;
    UPDATE structs.allocation SET source_id='1-990941' WHERE id='6-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.allocation SET source_id='1-990940',allocation_type='automated' WHERE id='6-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.allocation SET allocation_type='dynamic' WHERE id='6-990940';
    PERFORM signer.tx_allocation_delete('1-990940','6-990940');
    request_id:=pg_temp.energy_last();
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=8 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('6-990940@1-990940','6-990940','1-990940',8);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    -- A guild static/automated source also needs source Admin; a provider agreement cannot use this path.
    PERFORM signer.tx_allocation_delete('1-990941','6-990941');
    request_id:=pg_temp.energy_last();
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.permission SET val=256 WHERE id='8-queuekeyb@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.permission SET val=258 WHERE id='8-queuekeyb@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.allocation SET allocation_type='providerAgreement' WHERE id='6-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    -- Transfer is Admin, not Update; target may be a guild and must still exist.
    UPDATE structs.permission SET val=4 WHERE id='8-queuekeyb@0';
    PERFORM signer.tx_allocation_transfer('1-990941','6-990940','0-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.permission SET val=2 WHERE id='8-queuekeyb@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.allocation SET controller='1-990943' WHERE id='6-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
END $$;
ROLLBACK TO allocation; RELEASE allocation;

SAVEPOINT creation;
DO $$ DECLARE request_id INTEGER; BEGIN
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('3-990940@1-990940','3-990940','1-990940',256);
    UPDATE structs.permission SET val=256 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_allocation_create('1-990940','dynamic','3-990940',1,'');
    request_id:=pg_temp.energy_last();
    IF (SELECT flags FROM signer.tx WHERE id=request_id)<>'{"allocation-type":"dynamic","controller":"0-990940"}'::jsonb THEN RAISE EXCEPTION 'guild controller lost'; END IF;
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    PERFORM signer.tx_allocation_create('1-990940','dynamic','3-990940',1,'1-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=258 WHERE id IN ('8-queuekeya@0','3-990940@1-990940');
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.reactor SET owner='1-990941' WHERE id='3-990940';
    UPDATE structs.permission SET val=256 WHERE id IN ('8-queuekeya@0','3-990940@1-990940');
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    PERFORM signer.tx_allocation_create('1-990940','automated','4-990940',0,'');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    -- Personal substation default is the actor; guild ownership needs separate allocation-connection authority.
    PERFORM signer.tx_substation_create('1-990940','6-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('6-990940@1-990940','6-990940','1-990940',2048);
    UPDATE structs.permission SET val=2048 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    IF (SELECT args FROM signer.tx WHERE id=request_id)<>'["1-990940","6-990940"]'::jsonb THEN RAISE EXCEPTION 'missing substation owner'; END IF;
    PERFORM signer.tx_substation_create('1-990940','6-990940','0-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',2048);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
END $$;
ROLLBACK TO creation; RELEASE creation;

SAVEPOINT connections;
DO $$ DECLARE request_id INTEGER; BEGIN
    -- Receiving power requires no destination grant, but does require an accepting destination.
    UPDATE structs.permission SET val=2048 WHERE id='8-queuekeyb@0';
    PERFORM signer.tx_allocation_connect('1-990941','6-990940','4-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.substation SET deletion_pending=FALSE WHERE id='4-990940';
    UPDATE structs.allocation SET controller='1-990943' WHERE id='6-990940';
    PERFORM signer.tx_allocation_disconnect('1-990941','6-990940');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.allocation SET destination_id='4-990940' WHERE id='6-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    -- Player connect needs both player and station, never an arbitrary guild key.
    PERFORM signer.tx_substation_player_connect('1-990940','4-990940','1-990943');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('1-990943@1-990940','1-990943','1-990940',1024);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=2048 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    -- Disconnect accepts target authority even while its station is closing; station-only authority does not.
    UPDATE structs.permission SET val=1024 WHERE id IN ('8-queuekeya@0','8-queuekeyb@0');
    PERFORM signer.tx_substation_player_disconnect('1-990940','4-990941','1-990943');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    PERFORM signer.tx_substation_player_disconnect('1-990941','4-990941','1-990943');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.substation SET deletion_pending=FALSE WHERE id='4-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.player SET substation_id='4-990940' WHERE id='1-990943';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeyb',FALSE);
    -- Every migration target is checked; eight-rule cap does not truncate the list.
    PERFORM signer.tx_substation_player_migrate('1-990940','4-990940',ARRAY['1-990940','1-990943']);
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=4 WHERE id='1-990943@1-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
END $$;
ROLLBACK TO connections; RELEASE connections;

SAVEPOINT deletion_and_ugc;
DO $$ DECLARE request_id INTEGER; BEGIN
    PERFORM signer.tx_substation_delete('1-990940','4-990940','4-990941');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('4-990941@1-990940','4-990941','1-990940',1024);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    PERFORM signer.tx_substation_delete('1-990940','4-990940',NULL);
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    -- Guild-owned cosmetic policy follows that guild, not its human owner's membership.
    PERFORM signer.tx_substation_update_name('1-990940','4-990942','Power station');
    request_id:=pg_temp.energy_last(); PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',16777216);
    UPDATE structs.permission SET val=16777216 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player SET guild_id='' WHERE id='1-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET owner='1-990941' WHERE id='4-990942';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.player SET guild_id='0-990940' WHERE id='1-990941';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
END $$;
ROLLBACK TO deletion_and_ugc; RELEASE deletion_and_ugc;

SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_create('dynamic','1-990940',1,'1-990940')$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_substation_player_disconnect('4-990940','1-990940')$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_create('1-990940','dynamic','1-990940',0,'')$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_create('1-990940','bogus','1-990940',1,'')$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_update('1-990940','6-990940',1.1)$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_update('1-990940','6-990940',18446744073709551616)$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_allocation_transfer('1-990940','6-990940','')$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_substation_player_migrate('1-990940','4-990940',ARRAY['1-990940','1-990940'])$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_substation_player_migrate('1-990940','4-990940',ARRAY['1-990940',NULL])$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_substation_player_migrate('1-990940','4-990940',ARRAY[['1-990940']])$$);
SELECT pg_temp.energy_refuses($$SELECT signer.tx_substation_player_migrate('1-990940','4-990940',ARRAY[]::varchar[])$$);
DO $$ DECLARE request_id INTEGER; BEGIN
    PERFORM signer.tx_allocation_update('1-990940','6-990940',1);
    request_id:=pg_temp.energy_last();
    UPDATE signer.tx SET args='["6-990940","1e5"]' WHERE id=request_id;
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE signer.tx SET args='["6-990940","1"]' WHERE id=request_id;
    DELETE FROM signer.tx_authority WHERE tx_id=request_id;
    INSERT INTO signer.tx_authority(tx_id,check_type,object_id,permission) VALUES(request_id,'object','1-990940',1);
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
END $$;

SAVEPOINT many_players;
DO $$ DECLARE request_id INTEGER; target_list VARCHAR[]; claim JSONB; BEGIN
    INSERT INTO structs.player(id,primary_address)
        SELECT '1-'||id,'energykey'||id FROM generate_series(990950,990958) id;
    INSERT INTO structs.permission(id,object_id,player_id,val)
        SELECT '1-'||id||'@1-990940','1-'||id,'1-990940',1024 FROM generate_series(990950,990958) id;
    SELECT array_agg(('1-'||id)::varchar ORDER BY id) INTO target_list FROM generate_series(990950,990958) id;
    PERFORM signer.tx_substation_player_migrate('1-990940','4-990940',target_list);
    request_id:=pg_temp.energy_last();
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.permission SET val=4 WHERE id='1-990958@1-990940';
    PERFORM pg_temp.energy_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=1024 WHERE id='1-990958@1-990940';
    claim:=signer.CLAIM_TRANSACTION_V022();
    IF claim->'transaction'->>'id' IS DISTINCT FROM request_id::text OR claim->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'energy claim did not preserve the requested actor and all targets';
    END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(request_id,(claim->'transaction'->>'claim_token')::uuid,'fixture completed');
END $$;
ROLLBACK TO many_players; RELEASE many_players;

CREATE ROLE v022_energy_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_energy_caller;
GRANT SELECT ON signer.tx,signer.tx_authority,signer.role,signer.account,structs.player,structs.player_address,
    structs.permission,structs.permission_guild_rank,structs.guild,structs.substation,structs.allocation,structs.vault TO v022_energy_caller;
SET LOCAL ROLE v022_energy_caller;
SELECT signer.tx_substation_update_pfp('1-990940','4-990940','https://example.com/picture.png');
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(pg_temp.energy_last()) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'scoped energy caller could not prepare/read eligibility';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
