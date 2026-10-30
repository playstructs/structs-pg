\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
DO $$
DECLARE role_id INTEGER; request JSONB; bound JSONB; claim JSONB; saved JSONB; tx_id INTEGER; token UUID;
    address VARCHAR := 'structs1' || repeat('q',38); context RECORD;
BEGIN
    INSERT INTO structs.substation(id,owner,deletion_pending) VALUES('4-990940','0-990940',FALSE);
    UPDATE structs.guild SET entry_substation_id='4-990940' WHERE id='0-990940';
    INSERT INTO structs.player_internal_pending(username,guild_id) VALUES('role key fixture','0-990940') RETURNING structs.player_internal_pending.role_id INTO role_id;
    BEGIN
        PERFORM signer.PREPARE_ROLE_KEY_V022(role_id,127);
        RAISE EXCEPTION 'bootstrap accepted an invented primary grant';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    request := signer.PREPARE_ROLE_KEY_V022(role_id,33554431);
    IF request IS DISTINCT FROM signer.PREPARE_ROLE_KEY_V022(role_id,33554431) THEN RAISE EXCEPTION 'role restart replaced the key request'; END IF;
    bound := signer.BIND_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,address,'02' || repeat('ab',32),repeat('cd',64));
    IF bound->>'address'<>address OR bound->>'proxy_tx_id' IS NULL OR (bound->>'external_requested')::boolean THEN
        RAISE EXCEPTION 'existing guild authority did not queue the role proxy'; END IF;
    IF bound IS DISTINCT FROM signer.BIND_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,address,'02' || repeat('ab',32),repeat('cd',64)) THEN
        RAISE EXCEPTION 'role binding retry created another transaction'; END IF;
    IF signer.ACTIVATE_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,'1-990943',3353000,3353000) THEN
        RAISE EXCEPTION 'role activated without on-chain registration'; END IF;
    claim := signer.CLAIM_TRANSACTION_V022(); tx_id := (claim->'transaction'->>'id')::integer; token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,'role-fixture-bytes'::bytea,0,0,3353000,3353100);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
    PERFORM signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'lost response');
    IF bound IS DISTINCT FROM signer.BIND_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,address,'02' || repeat('ab',32),repeat('cd',64)) THEN
        RAISE EXCEPTION 'ambiguous role transaction was replaced'; END IF;
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,jsonb_build_object('stage','deliver_tx','hash',saved->>'tx_hash',
        'code','0','codespace','','log','','height','3353001','index','0','block_hash',repeat('B',64)));
    INSERT INTO structs.player(id,primary_address,guild_id) VALUES('1-990943',address,'0-990940');
    INSERT INTO structs.permission(id,object_type,object_index,object_id,player_id,val)
    VALUES('8-' || address || '@0','address',address,'1-990943','1-990943',33554431);
    IF signer.ACTIVATE_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,'1-990943',3353000,3353001) THEN
        RAISE EXCEPTION 'role activated before index covered its committed result'; END IF;
    UPDATE sync_state.sync_cursor SET last_height=3353001,tip_height=3353001;
    UPDATE structs.current_block SET height=3353001,tip_height=3353001;
    UPDATE sync_state.economy_contract SET last_height=3353001;
    IF NOT signer.ACTIVATE_ROLE_KEY_V022(role_id,(request->>'request_id')::uuid,'1-990943',3353001,3353001) THEN
        RAISE EXCEPTION 'confirmed matching role did not activate'; END IF;
    IF (SELECT status FROM signer.account WHERE id=(bound->>'account_id')::integer)<>'available' THEN
        RAISE EXCEPTION 'role account stayed unavailable after confirmed activation'; END IF;
END $$;
ROLLBACK;
