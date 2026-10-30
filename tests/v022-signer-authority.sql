-- Disposable Sqitch database only. Authority must follow current chain rows.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO structs.guild(id,owner) VALUES('0-990960','1-990961'),('0-990961','1-990963');
INSERT INTO structs.player(id,primary_address,guild_id,guild_rank) VALUES
    ('1-990960','authoritykeya','0-990960',10),
    ('1-990961','authoritykeyb','0-990961',18446744073709551615),
    ('1-990962','authoritykeyc','0-990960',10),
    ('1-990963','authoritykeyd','0-990961',10);
INSERT INTO structs.player_address(address,player_id,guild_id,status)
VALUES('authorityrestricted','1-990960','0-990960','approved');
INSERT INTO structs.permission(id,object_type,object_index,object_id,player_id,val) VALUES
    ('8-authoritykeya@0','address','authoritykeya','1-990960','1-990960',33554431),
    ('8-authoritykeyb@0','address','authoritykeyb','1-990961','1-990961',33554431),
    ('8-authoritykeyc@0','address','authoritykeyc','1-990962','1-990962',33554431),
    ('8-authoritykeyd@0','address','authoritykeyd','1-990963','1-990963',33554431),
    ('8-authorityrestricted@0','address','authorityrestricted','1-990960','1-990960',16);
INSERT INTO structs.substation(id,owner) VALUES('4-990960','0-990960'),('4-990961','1-990960');
INSERT INTO structs.provider(id,owner,access_policy)
VALUES('10-990960','0-990960','openMarket'),('10-990961','0-990960','guildMarket');
INSERT INTO structs.struct(id,owner,is_destroyed) VALUES('5-990960','1-990960',true);
INSERT INTO structs.allocation(id,controller) VALUES('6-990960','0-990960');
INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank) VALUES
    ('4-990960','0-990960',16,20),('4-990960','0-990960',32,9),
    ('4-990960','0-990960',2,20);
DO $$
DECLARE
    bad INTEGER;
BEGIN
    FOREACH bad IN ARRAY ARRAY[NULL,0,-1,33554432] LOOP
        IF signer.PERMISSION_CHECK('authoritykeya','1-990960',bad) THEN
            RAISE EXCEPTION 'invalid permission mask accepted';
        END IF;
    END LOOP;
    IF NOT signer.PERMISSION_CHECK('authoritykeya','1-990960',16)
        OR NOT signer.PERMISSION_CHECK('authoritykeya','4-990961',256)
        OR NOT signer.PERMISSION_CHECK('authoritykeyb','4-990960',256)
        OR NOT signer.PERMISSION_CHECK('authoritykeyb','6-990960',32) THEN
        RAISE EXCEPTION 'current player/guild ownership did not grant the requested operation';
    END IF;
    IF signer.PERMISSION_CHECK('authorityrestricted','4-990961',32)
        OR signer.PERMISSION_CHECK('authoritykeya','5-990960',16)
        OR signer.PERMISSION_CHECK('authoritykeya','4-990999',16)
        OR signer.PERMISSION_CHECK('missingkey','4-990960',16) THEN
        RAISE EXCEPTION 'key ceiling, destroyed or missing object check failed';
    END IF;
    IF NOT signer.PERMISSION_CHECK('authoritykeya','4-990960',16)
        OR signer.PERMISSION_CHECK('authoritykeya','4-990960',48)
        OR signer.PERMISSION_CHECK('authoritykeya','4-990960',2) THEN
        RAISE EXCEPTION 'rank threshold, combined mask or administration boundary failed';
    END IF;
    UPDATE structs.permission_guild_rank SET rank=10 WHERE object_id='4-990960' AND permission=32;
    IF NOT signer.PERMISSION_CHECK('authoritykeya','4-990960',48)
        OR signer.PERMISSION_CHECK('authorityrestricted','4-990960',48) THEN
        RAISE EXCEPTION 'rank must cover all bits and remain below signing-key ceiling';
    END IF;
    DELETE FROM structs.permission_guild_rank WHERE object_id='4-990960' AND permission=16;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('4-990960@1-990960','4-990960','1-990960',16);
    IF NOT signer.PERMISSION_CHECK('authoritykeya','4-990960',16)
        OR signer.PERMISSION_CHECK('authoritykeya','4-990960',48) THEN
        RAISE EXCEPTION 'incomplete direct and rank grants were incorrectly merged';
    END IF;
    UPDATE structs.permission SET val=18 WHERE id='4-990960@1-990960';
    IF NOT signer.PERMISSION_CHECK('authoritykeya','4-990960',2) THEN
        RAISE EXCEPTION 'direct administration was incorrectly refused';
    END IF;
    UPDATE structs.guild SET owner='1-990963' WHERE id='0-990960';
    IF signer.PERMISSION_CHECK('authoritykeyb','4-990960',256)
        OR NOT signer.PERMISSION_CHECK('authoritykeyd','4-990960',256) THEN
        RAISE EXCEPTION 'guild ownership was taken from stale sidecar data';
    END IF;
    UPDATE structs.player SET guild_id='0-990961',guild_rank=18446744073709551615 WHERE id='1-990962';
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990960','0-990961',32,18446744073709551615);
    IF NOT signer.PERMISSION_CHECK('authoritykeyc','4-990960',32) THEN
        RAISE EXCEPTION 'max uint64 rank comparison lost precision';
    END IF;
    UPDATE structs.permission_guild_rank SET rank=18446744073709551614
    WHERE object_id='4-990960' AND guild_id='0-990961' AND permission=32;
    IF signer.PERMISSION_CHECK('authoritykeyc','4-990960',32) THEN
        RAISE EXCEPTION 'adjacent uint64 ranks were conflated';
    END IF;
    UPDATE structs.player_address SET status='revoked' WHERE address='authorityrestricted';
    IF signer.PERMISSION_CHECK('authorityrestricted','1-990960',16) THEN
        RAISE EXCEPTION 'revoked address retained authority';
    END IF;
    UPDATE structs.player_address SET status='approved',player_id='1-990962' WHERE address='authorityrestricted';
    IF signer.PERMISSION_CHECK('authorityrestricted','1-990960',16)
        OR NOT signer.PERMISSION_CHECK('authorityrestricted','1-990962',16) THEN
        RAISE EXCEPTION 'reassigned address trusted old permission.player_id';
    END IF;
    INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990962','authorityrestricted',0);
    IF signer.PERMISSION_CHECK('authorityrestricted','1-990962',16) THEN
        RAISE EXCEPTION 'vault was accepted as a signing identity';
    END IF;
    IF NOT signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990960','1-990960')
        OR signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990960','0-990960')
        OR signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990961','1-990960') THEN
        RAISE EXCEPTION 'provider access was confused with collateral spending authority';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('10-990961@1-990960','10-990961','1-990960',262144);
    IF NOT signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990961','1-990960') THEN
        RAISE EXCEPTION 'authorized guild-market contract refused';
    END IF;
    UPDATE structs.permission SET val=262144 WHERE id='8-authoritykeya@0';
    IF signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990961','1-990960') THEN
        RAISE EXCEPTION 'provider-open key spent funds without token-transfer bit';
    END IF;
    UPDATE structs.permission SET val=33554431 WHERE id='8-authoritykeya@0';
    UPDATE structs.provider SET access_policy='closedMarket' WHERE id='10-990960';
    IF signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990960','1-990960')
        OR signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990999','1-990960') THEN
        RAISE EXCEPTION 'closed or missing provider accepted';
    END IF;
END $$;

-- Helpers use caller privileges. The signer role needs reads, never SUPERUSER.
CREATE ROLE v022_signer_authority_fixture NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_signer_authority_fixture;
GRANT SELECT ON structs.player,structs.player_address,structs.permission,structs.permission_guild_rank,
    structs.vault,structs.guild,structs.substation,structs.provider TO v022_signer_authority_fixture;
SET LOCAL ROLE v022_signer_authority_fixture;
SELECT 1 / signer.PERMISSION_CHECK('authoritykeya','4-990961',256)::int;
SELECT 1 / signer.CAN_OPEN_AGREEMENT('authoritykeya','10-990961','1-990960')::int;
ROLLBACK;
