-- Disposable PostgreSQL only; all changes roll back.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.guild(id,owner) VALUES('0-990941','1-990940');
INSERT INTO structs.player(id,primary_address,guild_id,guild_rank) VALUES('1-990943','cosmetickeyc','0-990940',20);
INSERT INTO structs.planet(id,owner) VALUES('2-990940','1-990943');
INSERT INTO structs.substation(id,owner,deletion_pending) VALUES
    ('4-990940','0-990940',FALSE),('4-990941','1-990943',FALSE);
CREATE FUNCTION pg_temp.cosmetic_last() RETURNS INTEGER LANGUAGE sql AS $$ SELECT max(id) FROM signer.tx $$;
CREATE FUNCTION pg_temp.cosmetic_eligible(_id INTEGER,_address VARCHAR,_expected BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_id) WHERE address=_address) IS DISTINCT FROM _expected THEN
        RAISE EXCEPTION 'cosmetic % eligibility for % should be %',_id,_address,_expected;
    END IF;
END $$;
CREATE FUNCTION pg_temp.cosmetic_refuses(statement TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement; EXCEPTION WHEN invalid_parameter_value THEN RETURN; END;
    RAISE EXCEPTION 'invalid cosmetic input accepted: %',statement;
END $$;

SAVEPOINT normal_edits;
DO $$ DECLARE request_id INTEGER; BEGIN
    UPDATE structs.permission SET val=4 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_player_update_name('1-990940','New name');
    request_id:=pg_temp.cosmetic_last();
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.permission SET val=16777216 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',16777216);
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player SET guild_id='' WHERE id='1-990940';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    -- Normal planet edits permit direct Update, independently of guild policy.
    UPDATE structs.permission SET val=4 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_planet_update_name('1-990940','2-990940','Planet');
    request_id:=pg_temp.cosmetic_last(); PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('2-990940@1-990940','2-990940','1-990940',4);
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    DELETE FROM structs.planet WHERE id='2-990940';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
END $$;
ROLLBACK TO normal_edits; RELEASE normal_edits;

SAVEPOINT moderation;
DO $$ DECLARE request_id INTEGER; claim JSONB; BEGIN
    PERFORM signer.tx_guild_moderate_player_name('1-990940','0-990940','1-990943','Moderated name');
    request_id:=pg_temp.cosmetic_last();
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeyb',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',16777216);
    UPDATE structs.permission SET val=16777216 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    -- Actor owns the second guild too, but that must not move this request's moderation boundary.
    UPDATE structs.player SET guild_id='0-990941' WHERE id='1-990943';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.player SET guild_id='0-990940' WHERE id='1-990943';
    UPDATE structs.permission SET val=4 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    UPDATE structs.permission SET val=16777216 WHERE id='8-queuekeya@0';
    claim:=signer.CLAIM_TRANSACTION_V022();
    IF claim->'transaction'->>'id' IS DISTINCT FROM request_id::text OR claim->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'moderation changed the requested actor';
    END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(request_id,(claim->'transaction'->>'claim_token')::uuid,'fixture completed');
    PERFORM signer.tx_guild_moderate_planet_name('1-990940','0-990940','2-990940','Planet');
    request_id:=pg_temp.cosmetic_last(); PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.planet SET owner='1-990940' WHERE id='2-990940';
    UPDATE structs.player SET guild_id='0-990941' WHERE id='1-990940';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    -- Guild-owned substations follow their owning guild even if its human owner changes membership.
    PERFORM signer.tx_guild_moderate_substation_name('1-990940','0-990940','4-990940','Substation');
    request_id:=pg_temp.cosmetic_last(); PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.player SET guild_id='0-990941' WHERE id='1-990941';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET owner='0-990941' WHERE id='4-990940';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
END $$;
ROLLBACK TO moderation; RELEASE moderation;

SAVEPOINT guild_settings;
DO $$ DECLARE request_id INTEGER; BEGIN
    -- The actual guild name/PFP handlers require Update; GuildUGC alone does not suffice.
    UPDATE structs.permission SET val=16777216 WHERE id='8-queuekeyb@0';
    PERFORM signer.tx_guild_update_name('1-990941','0-990940','Guild');
    request_id:=pg_temp.cosmetic_last(); PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeyb',FALSE);
    UPDATE structs.permission SET val=4 WHERE id='8-queuekeyb@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeyb',TRUE);
    UPDATE structs.guild SET owner='1-990943' WHERE id='0-990940';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeyb',FALSE);
    -- Guild setting and destination permission are independent.
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('0-990940@1-990940','0-990940','1-990940',65536);
    PERFORM signer.tx_guild_update_entry_substation_id('1-990940','0-990940','4-990941');
    request_id:=pg_temp.cosmetic_last(); PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES('4-990941@1-990940','4-990941','1-990940',1024);
    UPDATE structs.permission SET val=66560 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990941';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
    PERFORM signer.tx_guild_update_entry_substation_id('1-990940','0-990940',NULL);
    request_id:=pg_temp.cosmetic_last();
    UPDATE structs.permission SET val=65536 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',TRUE);
    IF (SELECT args FROM signer.tx WHERE id=request_id)<>'["0-990940",""]'::jsonb THEN RAISE EXCEPTION 'empty entry argument changed'; END IF;
END $$;
ROLLBACK TO guild_settings; RELEASE guild_settings;

SELECT pg_temp.cosmetic_refuses($$SELECT signer.tx_planet_update_name('1-990940','2-999999','Missing')$$);
SELECT pg_temp.cosmetic_refuses($$SELECT signer.tx_player_update_name('1-990940',NULL)$$);
SELECT pg_temp.cosmetic_refuses($$SELECT signer.tx_guild_update_entry_substation_id('1-990940','0-990940','4-18446744073709551616')$$);
DO $$ DECLARE request_id INTEGER; BEGIN
    PERFORM signer.tx_player_update_pfp_cr_attributes('1-990940','{"name":"quoted value","count":18446744073709551615}');
    request_id:=pg_temp.cosmetic_last();
    IF (SELECT args->>1 FROM signer.tx WHERE id=request_id)<>'{"name":"quoted value","count":18446744073709551615}' THEN
        RAISE EXCEPTION 'client attributes were parsed or rounded';
    END IF;
    UPDATE signer.tx SET args='{}' WHERE id=request_id;
    PERFORM pg_temp.cosmetic_eligible(request_id,'queuekeya',FALSE);
END $$;

CREATE ROLE v022_cosmetic_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_cosmetic_caller;
GRANT SELECT ON signer.tx,signer.tx_authority,signer.role,signer.account,structs.player,structs.player_address,
    structs.permission,structs.permission_guild_rank,structs.guild,structs.substation,structs.planet,structs.vault TO v022_cosmetic_caller;
SET LOCAL ROLE v022_cosmetic_caller;
SELECT signer.tx_guild_update_pfp('1-990941','0-990940','https://example.com/image.png');
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(pg_temp.cosmetic_last()) WHERE address='queuekeyb') THEN
        RAISE EXCEPTION 'scoped cosmetic caller could not prepare/read eligibility';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
