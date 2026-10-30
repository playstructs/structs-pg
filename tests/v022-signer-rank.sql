-- Disposable database only; installed wrappers and current claim authority.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.substation(id,owner) VALUES('4-990940','1-990941');
DO $$
DECLARE request signer.tx%ROWTYPE; bad NUMERIC;
BEGIN
    PERFORM signer.tx_guild_update_entry_rank('1-990940','0-990940',18446744073709551615);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["18446744073709551615"]' OR request.permission_requirement<>2
        OR request.requested_player_id<>'1-990940' OR request.flags<>'{"guild-id":"0-990940"}'
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'entry rank lost uint64, actor or guild administration requirement';
    END IF;
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('0-990940','0-990940',2,18446744073709551615);
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'rank-derived administration selected a signer';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('0-990940@1-990940','0-990940','1-990940',2);
    UPDATE structs.permission SET val=32768 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'obsolete join-constraint key authorized free rank administration';
    END IF;
    UPDATE structs.permission SET val=2 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'direct guild admin could not set entry rank';
    END IF;
    PERFORM signer.tx_guild_update_entry_rank('1-990940',NULL,9007199254740993);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["9007199254740993"]' OR request.flags<>'{"guild-id":"0-990940"}' THEN
        RAISE EXCEPTION 'default guild or exact entry rank changed';
    END IF;
    -- Current guild owners need not be members of the guild they administer.
    UPDATE structs.player SET guild_id=NULL WHERE id='1-990941';
    PERFORM signer.tx_guild_update_entry_rank('1-990941','0-990940',1);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeyb') THEN
        RAISE EXCEPTION 'guildless current owner could not administer its guild';
    END IF;
    PERFORM signer.tx_player_update_guild_rank('1-990941','1-990940',18446744073709551615,'0-990940');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["1-990940","18446744073709551615"]'
        OR request.requested_player_id<>'1-990941' OR request.object_id<>'0-990940'
        OR request.permission_requirement<>2
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeyb') THEN
        RAISE EXCEPTION 'player rank confused target identity with the guild administrator';
    END IF;
    BEGIN
        PERFORM signer.tx_player_update_guild_rank('1-990940','1-990941',1,'0-990940');
        RAISE EXCEPTION 'nonmember target accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_player_update_guild_rank('1-990940','1-990949',1,'0-990940');
        RAISE EXCEPTION 'missing target accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    -- Administration and the granted/revoked permission are separate checks.
    -- A direct admin can hold the other bit through a valid rank register.
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('4-990940@1-990940','4-990940','1-990940',2);
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990940','0-990940',16,10);
    PERFORM signer.tx_permission_guild_rank_set('1-990940','4-990940','0-990940',16,18446744073709551615);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["4-990940","0-990940","16","18446744073709551615"]'
        OR (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>2
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'rank grant failed to require the key own granted permission';
    END IF;
    UPDATE structs.permission SET val=18 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'separate admin/rank checks incorrectly required one combined direct grant';
    END IF;
    PERFORM signer.tx_permission_guild_rank_revoke('1-990940','4-990940','0-990940',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["4-990940","0-990940","16"]'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'authorized rank revocation refused';
    END IF;
    DELETE FROM structs.permission_guild_rank WHERE object_id='4-990940' AND permission=16;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'rank revocation ignored lost subject permission';
    END IF;
    -- Admin itself must not create duplicate queue rules or become rank-derived.
    PERFORM signer.tx_permission_guild_rank_set('1-990940','4-990940','0-990940',2,10);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF (SELECT count(*) FROM signer.tx_authority WHERE tx_id=request.id)<>1
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'same admin/permission rule was not represented once';
    END IF;
    PERFORM signer.tx_permission_guild_rank_revoke('1-990940','4-990940','0-990940',2);
    DELETE FROM structs.permission WHERE id='4-990940@1-990940';
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990940','0-990940',2,10);
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'rank administration substituted for removed direct admin';
    END IF;

    FOREACH bad IN ARRAY ARRAY[NULL,-1,0,1.1,18446744073709551616,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_guild_update_entry_rank('1-990940','0-990940',bad);
            RAISE EXCEPTION 'invalid entry rank accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
        BEGIN
            PERFORM signer.tx_player_update_guild_rank('1-990941','1-990940',bad,'0-990940');
            RAISE EXCEPTION 'invalid player rank accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
        BEGIN
            PERFORM signer.tx_permission_guild_rank_set('1-990940','4-990940','0-990940',16,bad);
            RAISE EXCEPTION 'invalid permission rank accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,0,1.1,33554432,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_permission_guild_rank_set('1-990940','4-990940','0-990940',bad,1);
            RAISE EXCEPTION 'invalid rank permission accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
        BEGIN
            PERFORM signer.tx_permission_guild_rank_revoke('1-990940','4-990940','0-990940',bad);
            RAISE EXCEPTION 'invalid revocation permission accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        PERFORM signer.tx_guild_update_entry_rank('1-990940','0-990949',1);
        RAISE EXCEPTION 'missing guild accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_permission_guild_rank_set('1-990940','4-990940','0-990949',16,1);
        RAISE EXCEPTION 'missing permission guild accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_player_update_guild_rank('1-990940',1,'0-990940');
        RAISE EXCEPTION 'legacy rank setter silently selected an acting player';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_permission_guild_rank_set('4-990940','0-990940',16,1);
        RAISE EXCEPTION 'legacy permission setter silently selected an acting player';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_permission_guild_rank_revoke('4-990940','0-990940',16);
        RAISE EXCEPTION 'legacy permission revoker silently selected an acting player';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract IS DISTINCT FROM 'v022-1'
        OR EXISTS (SELECT 1 FROM jsonb_array_elements(args) a WHERE jsonb_typeof(a)<>'string')) THEN
        RAISE EXCEPTION 'rank wrappers lost the versioned contract or exact string arguments';
    END IF;
END $$;
ROLLBACK;
