-- Disposable database only. Exercise current grants through the actual claim.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
INSERT INTO structs.player_address(address,player_id,status)
VALUES('permissiontarget','1-990940','approved');
INSERT INTO structs.permission(id,object_id,player_id,val)
VALUES('8-permissiontarget@0','1-990940','1-990940',16);
INSERT INTO structs.substation(id,owner) VALUES('4-990940','1-990941');
INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990940','permissionvault',0);
DO $$
DECLARE request signer.tx%ROWTYPE; claimed JSONB; bad NUMERIC; checks JSONB; before_count BIGINT;
BEGIN
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_permission_set_on_address('1-990940','permissiontarget',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id<>'1-990940' OR request.args<>'["permissiontarget","16"]'
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=request.id
            AND check_type='permission-address' AND object_id='permissiontarget'
            AND subject_id='' AND operation='set' AND permission=16)
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'address replacement lost actor, exact args or explicit mutation rule';
    END IF;
    -- The target gained migrate authority after enqueue. A transfer-only key
    -- must not erase it; freezing the old mask would incorrectly claim this.
    UPDATE structs.permission SET val=80 WHERE id='8-permissiontarget@0';
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'claim ignored the target''s newly acquired permission';
    END IF;
    UPDATE structs.permission SET val=80 WHERE id='8-queuekeya@0';
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'transaction'->>'id'<>request.id::text
        OR claimed->'account'->>'address'<>'queuekeya' THEN
        RAISE EXCEPTION 'correct replacement key was not reserved atomically';
    END IF;
    UPDATE signer.account SET status='available' WHERE id=990940;
    PERFORM signer.tx_permission_set_on_address('1-990940','permissiontarget',0);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["permissiontarget","0"]'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya')
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'zero replacement bypassed authority over the old grant';
    END IF;
    DELETE FROM structs.permission WHERE id='8-permissiontarget@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'absent grant plus zero replacement passed a permissionless check';
    END IF;
    INSERT INTO structs.permission(id,val) VALUES('8-permissiontarget@0',80);
    UPDATE structs.player_address SET player_id='1-990941' WHERE address='permissiontarget';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'reassigned subject address kept its former owner''s authority';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('1-990941@1-990940','1-990941','1-990940',80);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'explicit current subject-owner grant was ignored';
    END IF;
    UPDATE structs.player_address SET status='revoked' WHERE address='permissiontarget';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'revoked subject retained permission-mutation authority';
    END IF;
    UPDATE structs.player_address SET status='approved',player_id='1-990940' WHERE address='permissiontarget';
    UPDATE structs.permission SET val=NULL WHERE id='8-permissiontarget@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'unknown target mask was treated as a known zero';
    END IF;
    UPDATE structs.permission SET val=80 WHERE id='8-permissiontarget@0';

    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_permission_set_on_address('1-990940','queuekeya',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'full-access signer could downgrade its current primary';
    END IF;
    PERFORM signer.tx_permission_revoke_on_address('1-990940','queuekeya',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'primary revoke escaped full-access preservation';
    END IF;
    PERFORM signer.tx_permission_set_on_address('1-990940','queuekeya',33554431);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'primary full-access preservation refused';
    END IF;
    PERFORM signer.tx_permission_set_on_address('1-990940','permissiontarget',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    UPDATE structs.player SET primary_address='permissiontarget' WHERE id='1-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'primary rotation after enqueue was ignored';
    END IF;
    UPDATE structs.player SET primary_address='queuekeya' WHERE id='1-990940';
    PERFORM signer.tx_permission_grant_on_address('1-990940','permissiontarget',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'grant unnecessarily required the target''s existing other bits';
    END IF;
    PERFORM signer.tx_permission_revoke_on_address('1-990940','permissiontarget',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'secondary revoke unnecessarily required unrelated target bits';
    END IF;
    BEGIN
        PERFORM signer.tx_permission_set_on_address('1-990940','permissionvault',16);
        RAISE EXCEPTION 'vault became a signing-permission subject';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    -- Admin alone does not authorize spending/changing another permission.
    INSERT INTO structs.permission(id,object_id,player_id,val) VALUES
        ('4-990940@1-990940','4-990940','1-990940',2),
        ('4-990940@1-990941','4-990940','1-990941',64);
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990940','0-990940',16,10);
    UPDATE structs.permission SET val=18 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_permission_grant_on_object('1-990940','4-990940','1-990941',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>'["4-990940","1-990941","16"]'
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'independent direct admin and rank permission were incorrectly combined';
    END IF;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'permission-only key escaped administration ceiling';
    END IF;
    PERFORM signer.tx_permission_revoke_on_object('1-990940','4-990940','1-990941',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'authorized object revoke refused';
    END IF;
    PERFORM signer.tx_permission_set_on_object('1-990940','4-990940','1-990941',16);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'object replacement ignored the target''s old migrate grant';
    END IF;
    UPDATE structs.permission SET val=82 WHERE id='8-queuekeya@0';
    UPDATE structs.permission SET val=66 WHERE id='4-990940@1-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'replacement combined partial direct and rank grants for the old-plus-new mask';
    END IF;
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990940','0-990940',64,10);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'full rank grant plus direct admin failed';
    END IF;
    DELETE FROM structs.permission WHERE id='4-990940@1-990940';
    INSERT INTO structs.permission_guild_rank(object_id,guild_id,permission,rank)
    VALUES('4-990940','0-990940',2,10);
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'rank-derived admin authorized object permission mutation';
    END IF;
    UPDATE structs.substation SET owner='1-990940' WHERE id='4-990940';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'current object owner was not recognized';
    END IF;
    PERFORM signer.tx_permission_set_on_object('1-990940','4-990940','1-990941',0);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'authorized object grant removal refused';
    END IF;
    UPDATE structs.permission SET val=18 WHERE id='8-queuekeya@0';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'zero object replacement bypassed old-mask key ceiling';
    END IF;

    BEGIN
        PERFORM signer.tx_permission_set_on_object('1-990940','4-990940','1-990949',16);
        RAISE EXCEPTION 'missing grant target accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_permission_set_on_object('1-990940','4-990949','1-990941',16);
        RAISE EXCEPTION 'missing object accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,1.1,33554432,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_permission_set_on_address('1-990940','permissiontarget',bad);
            RAISE EXCEPTION 'invalid address permission mask accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
        BEGIN
            PERFORM signer.tx_permission_set_on_object('1-990940','4-990940','1-990941',bad);
            RAISE EXCEPTION 'invalid object permission mask accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    BEGIN
        PERFORM signer.tx_permission_grant_on_address('1-990940','permissiontarget',0);
        RAISE EXCEPTION 'zero grant accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_permission_revoke_on_object('1-990940','4-990940','1-990941',0);
        RAISE EXCEPTION 'zero revoke accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    SELECT count(*) INTO before_count FROM signer.tx;
    FOREACH checks IN ARRAY ARRAY[
        '[{"check_type":"permission-address","object_id":"permissiontarget","permission":0}]',
        '[{"check_type":"permission-address","object_id":"permissiontarget","permission":0,"operation":"set","subject_id":null}]',
        '[{"check_type":"object","object_id":"1-990940","permission":16,"operation":"set"}]'
    ]::JSONB[] LOOP
        BEGIN
            PERFORM signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','permission-set-on-address','[]','{}',checks);
            RAISE EXCEPTION 'partial or ambiguous mutation rule accepted';
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    IF (SELECT count(*) FROM signer.tx)<>before_count THEN RAISE EXCEPTION 'invalid mutation left a queued request'; END IF;
    BEGIN
        INSERT INTO signer.tx_authority(tx_id,check_type,object_id,permission)
        VALUES(request.id,'permission-object','4-990940',0);
        RAISE EXCEPTION 'incomplete mutation rule inserted directly';
    EXCEPTION WHEN check_violation THEN NULL; END;
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract IS DISTINCT FROM 'v022-1'
        OR requested_player_id<>'1-990940'
        OR EXISTS (SELECT 1 FROM jsonb_array_elements(args) a WHERE jsonb_typeof(a)<>'string')) THEN
        RAISE EXCEPTION 'permission wrappers lost actor or exact string arguments';
    END IF;
END $$;

DELETE FROM signer.tx;
UPDATE structs.permission SET val=80 WHERE id='8-queuekeya@0';
CREATE ROLE v022_mutation_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_mutation_caller;
GRANT SELECT ON signer.role,signer.tx_authority,structs.player,structs.player_address,
    structs.permission,structs.permission_guild_rank,structs.vault,structs.guild TO v022_mutation_caller;
GRANT SELECT,UPDATE ON signer.tx,signer.account TO v022_mutation_caller;
GRANT EXECUTE ON FUNCTION signer.CLAIM_TRANSACTION_V022(),structs.api_readiness(TEXT[]) TO v022_mutation_caller;
SET LOCAL ROLE v022_mutation_caller;
DO $$
DECLARE claimed JSONB;
BEGIN
    PERFORM signer.tx_permission_set_on_address('1-990940','permissiontarget',0);
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'account'->>'address'<>'queuekeya'
        OR claimed->'transaction'->'args'<>'["permissiontarget","0"]' THEN
        RAISE EXCEPTION 'scoped non-superuser could not enqueue and claim a permission replacement';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
