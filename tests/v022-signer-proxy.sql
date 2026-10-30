\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
DO $$
DECLARE address VARCHAR := 'structs1' || repeat('q',38); request JSONB; claim JSONB;
BEGIN
    INSERT INTO structs.substation(id,owner,deletion_pending) VALUES('4-990940','0-990940',FALSE);
    UPDATE structs.guild SET entry_substation_id='4-990940' WHERE id='0-990940';
    request := signer.CREATE_PROXY_TRANSACTION_V022('1-990941','0-990940',address,'02' || repeat('ab',32),repeat('cd',64),
        '{"player-name":"TSA Role","player-pfp-client-render-attributes":"{}"}');
    IF NOT signer.PROXY_CONTEXT_CHECK_V022((request->>'id')::int,'queuekeyb') THEN
        RAISE EXCEPTION 'eligible guild proxy request was rejected'; END IF;
    IF signer.PROXY_CONTEXT_CHECK_V022((request->>'id')::int,'queuekeya') THEN
        RAISE EXCEPTION 'ungranted guild member could proxy join'; END IF;
    UPDATE structs.player SET guild_id='' WHERE id='1-990941';
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'guild owner outside the destination guild could proxy join'; END IF;
    UPDATE structs.player SET guild_id='0-990940' WHERE id='1-990941';
    UPDATE structs.substation SET deletion_pending=TRUE WHERE id='4-990940';
    IF signer.CLAIM_TRANSACTION_V022() IS NOT NULL THEN RAISE EXCEPTION 'proxy used a closing entry station'; END IF;
    UPDATE structs.substation SET deletion_pending=FALSE WHERE id='4-990940';
    claim := signer.CLAIM_TRANSACTION_V022();
    IF claim->'account'->>'address'<>'queuekeyb' THEN RAISE EXCEPTION 'proxy selected the wrong actor'; END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022((claim->'transaction'->>'id')::int,
        (claim->'transaction'->>'claim_token')::uuid,'fixture complete');
    INSERT INTO structs.player_pending(primary_address,guild_id,pubkey,signature,username,pfp_client_render_attributes)
    VALUES('structs1' || repeat('p',38),'0-990940','02' || repeat('ab',32),repeat('cd',64),'New Player','{}');
    SELECT to_jsonb(t) INTO request FROM signer.tx t WHERE status='pending' ORDER BY id DESC LIMIT 1;
    IF request->>'contract'<>'v022-1' OR request->'flags' ? 'player-pfp-cr-attributes'
        OR NOT request->'flags' ? 'player-pfp-client-render-attributes' THEN
        RAISE EXCEPTION 'signup trigger still queued a legacy request or obsolete flag'; END IF;
    IF signer.CLAIM_TRANSACTION_V022() IS NULL THEN RAISE EXCEPTION 'new signup request was not claimable'; END IF;
END $$;
ROLLBACK;
