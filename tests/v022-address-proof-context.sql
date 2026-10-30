-- Disposable Sqitch database only. No fixture rows survive this transaction.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE structs_webapp;
INSERT INTO structs.player_address_pending(code,address,signature,pubkey,permissions)
VALUES('proof-context-fixture','proof-context-address','signature','pubkey',32);
DO $$
DECLARE
    invalid_value NUMERIC;
    exact_nonce NUMERIC;
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'requires non-superuser webapp role';
    END IF;
    IF EXISTS (SELECT 1 FROM structs.player_address_pending
        WHERE code='proof-context-fixture' AND (player_id IS NOT NULL OR guild_id IS NOT NULL
            OR proof_chain_id IS NOT NULL OR proof_protocol IS NOT NULL OR proof_nonce IS NOT NULL
            OR proof_height IS NOT NULL OR proof_timeout_height IS NOT NULL)) THEN
        RAISE EXCEPTION 'legacy insert invented proof context';
    END IF;
    BEGIN
        UPDATE structs.player_address_pending SET player_id='1-990980' WHERE code='proof-context-fixture';
        RAISE EXCEPTION 'accepted partial proof context';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE structs.player_address_pending SET player_id='1-990980',guild_id='0-990980',
        proof_chain_id='structstestnet-111',proof_protocol='v0.21.0',
        proof_height=3352998,proof_timeout_height=3352999
    WHERE code='proof-context-fixture';
    BEGIN
        UPDATE structs.player_address_pending SET proof_timeout_height=3352997 WHERE code='proof-context-fixture';
        RAISE EXCEPTION 'accepted expired legacy context';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        UPDATE structs.player_address_pending SET proof_nonce=0 WHERE code='proof-context-fixture';
        RAISE EXCEPTION 'legacy context accepted a nonce';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE structs.player_address_pending SET proof_protocol='v0.22.0',proof_nonce=0,
        proof_height=3353000,proof_timeout_height=0 WHERE code='proof-context-fixture';
    FOREACH exact_nonce IN ARRAY ARRAY[0,1,9007199254740993,18446744073709551615]::NUMERIC[] LOOP
        UPDATE structs.player_address_pending SET proof_nonce=exact_nonce WHERE code='proof-context-fixture';
        IF (SELECT proof_nonce::text <> exact_nonce::text FROM structs.player_address_pending WHERE code='proof-context-fixture') THEN
            RAISE EXCEPTION 'nonce lost precision: %', exact_nonce;
        END IF;
    END LOOP;
    FOREACH invalid_value IN ARRAY ARRAY[NULL,-1,0.1,18446744073709551615.1,18446744073709551616,'NaN','Infinity','-Infinity']::NUMERIC[] LOOP
        BEGIN
            UPDATE structs.player_address_pending SET proof_nonce=invalid_value WHERE code='proof-context-fixture';
            RAISE EXCEPTION 'accepted invalid nonce: %',invalid_value;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    FOREACH invalid_value IN ARRAY ARRAY[NULL,-1,0,3353000.1,9007199254740992,'NaN','Infinity','-Infinity']::NUMERIC[] LOOP
        BEGIN
            UPDATE structs.player_address_pending SET proof_height=invalid_value WHERE code='proof-context-fixture';
            RAISE EXCEPTION 'accepted invalid height: %',invalid_value;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    FOREACH invalid_value IN ARRAY ARRAY[NULL,-1,0.1,1,'NaN','Infinity','-Infinity']::NUMERIC[] LOOP
        BEGIN
            UPDATE structs.player_address_pending SET proof_timeout_height=invalid_value WHERE code='proof-context-fixture';
            RAISE EXCEPTION 'accepted invalid current timeout: %',invalid_value;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    BEGIN
        UPDATE structs.player_address_pending SET proof_protocol='unknown' WHERE code='proof-context-fixture';
        RAISE EXCEPTION 'accepted unknown protocol';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        DELETE FROM structs.player_address_pending WHERE code='proof-context-fixture';
        RAISE EXCEPTION 'webapp unexpectedly has pending-delete privilege';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;
INSERT INTO structs.player_address_activation_code(player_id,code,logged_in_address)
VALUES('1-990980','proof-context-fixture','proof-context-approver');
SELECT code FROM structs.player_address_activation_code WHERE code='proof-context-fixture' FOR UPDATE;
DELETE FROM structs.player_address_activation_code WHERE code='proof-context-fixture';
ROLLBACK;
