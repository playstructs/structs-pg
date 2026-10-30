-- Deploy structs-pg:function-signer-proxy-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
    RAISE EXCEPTION 'proxy onboarding requires the coordinated v022-1 signer contract'; END IF; END $$;
CREATE TABLE signer.tx_proxy_proof (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx(id) ON DELETE CASCADE,
    guild_id VARCHAR NOT NULL,
    address VARCHAR NOT NULL,
    player_id VARCHAR NOT NULL,
    proof_nonce NUMERIC NOT NULL CHECK (proof_nonce=trunc(proof_nonce) AND proof_nonce BETWEEN 0 AND 18446744073709551615),
    source_height BIGINT NOT NULL CHECK (source_height>=3353000)
);
CREATE TRIGGER proxy_proof_immutable_v022 BEFORE UPDATE ON signer.tx_proxy_proof
    FOR EACH ROW EXECUTE FUNCTION signer.REGISTRATION_PROOF_IMMUTABLE();

CREATE FUNCTION signer.PROXY_CONTEXT_CHECK_V022(_tx_id INTEGER,_address VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE; _proof signer.tx_proxy_proof%ROWTYPE;
    _actor structs.player%ROWTYPE; _target structs.player%ROWTYPE; _guild structs.guild%ROWTYPE;
    _player_id VARCHAR; _station VARCHAR; _nonce NUMERIC;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    SELECT * INTO _proof FROM signer.tx_proxy_proof WHERE tx_id=_tx_id;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.module<>'structs'
        OR _tx.command<>'guild-membership-join-proxy' OR _tx.object_id<>_proof.guild_id
        OR jsonb_array_length(_tx.args)<>3 OR _tx.args->>0<>_proof.address
        OR _tx.args->>1 !~ '^(02|03)[0-9a-f]{64}$' OR _tx.args->>2 !~ '^[0-9a-f]{128}([0-9a-f]{2})?$'
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=_tx_id
            AND check_type='object' AND object_id=_proof.guild_id AND permission=512 AND subject_id='' AND operation='')
        OR EXISTS (SELECT 1 FROM jsonb_each(_tx.flags) f WHERE f.key NOT IN
            ('player-name','player-pfp','player-pfp-client-render-attributes','substation-id') OR jsonb_typeof(f.value)<>'string') THEN
        RETURN FALSE;
    END IF;
    SELECT p.* INTO _actor FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved' AND p.id=_tx.requested_player_id;
    IF NOT FOUND OR _actor.guild_id IS DISTINCT FROM _proof.guild_id
        OR signer.PERMISSION_CHECK(_address,_proof.guild_id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    SELECT * INTO _guild FROM structs.guild WHERE id=_proof.guild_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;
    _station := COALESCE(NULLIF(_tx.flags->>'substation-id',''),_guild.entry_substation_id);
    IF NOT EXISTS (SELECT 1 FROM structs.substation WHERE id=_station AND deletion_pending IS FALSE)
        OR (NULLIF(_tx.flags->>'substation-id','') IS NOT NULL
            AND signer.PERMISSION_CHECK(_address,_station,1024) IS DISTINCT FROM TRUE) THEN RETURN FALSE; END IF;
    IF EXISTS (SELECT 1 FROM structs.vault WHERE address=_proof.address) THEN RETURN FALSE; END IF;
    SELECT player_id INTO _player_id FROM structs.player_address WHERE address=_proof.address AND status='approved';
    IF COALESCE(_player_id,'') IS DISTINCT FROM _proof.player_id THEN RETURN FALSE; END IF;
    IF NULLIF(_player_id,'') IS NULL THEN RETURN _proof.proof_nonce=0; END IF;
    SELECT * INTO _target FROM structs.player WHERE id=_player_id;
    IF NOT FOUND OR NULLIF(_target.guild_id,'') IS NOT NULL OR NOT EXISTS (
        SELECT 1 FROM structs.permission WHERE id='8-' || _proof.address || '@0' AND (val & 512)=512) THEN RETURN FALSE; END IF;
    SELECT val INTO _nonce FROM structs.grid WHERE id='10-' || _player_id;
    RETURN COALESCE(_nonce,0)=_proof.proof_nonce;
END
$BODY$;

CREATE FUNCTION signer.CREATE_PROXY_TRANSACTION_V022(_actor_id VARCHAR,_guild_id VARCHAR,
    _address VARCHAR,_pubkey VARCHAR,_signature VARCHAR,_flags JSONB)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _request JSONB; _context RECORD; _player_id VARCHAR; _nonce NUMERIC; _account RECORD;
BEGIN
    IF _guild_id IS NULL OR _guild_id !~ '^0-[1-9][0-9]*$'
        OR _address IS NULL OR _address !~ '^structs1[ac-hj-np-z02-9]{38}$'
        OR _pubkey IS NULL OR _pubkey !~* '^(02|03)[0-9a-f]{64}$'
        OR _signature IS NULL OR _signature !~* '^[0-9a-f]{128}([0-9a-f]{2})?$'
        OR _flags IS NULL OR jsonb_typeof(_flags)<>'object' THEN
        RAISE EXCEPTION 'invalid proxy registration request' USING ERRCODE='22023';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(_flags) f WHERE f.key NOT IN
        ('player-name','player-pfp','player-pfp-client-render-attributes','substation-id') OR jsonb_typeof(f.value)<>'string') THEN
        RAISE EXCEPTION 'invalid proxy registration flags' USING ERRCODE='22023'; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    SELECT player_id INTO _player_id FROM structs.player_address WHERE address=_address AND status='approved';
    SELECT val INTO _nonce FROM structs.grid WHERE id='10-' || _player_id;
    _request := signer.CREATE_TRANSACTION_V022(_actor_id,_guild_id,'structs','guild-membership-join-proxy',
        jsonb_build_array(_address,lower(_pubkey),lower(_signature)),_flags,
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_guild_id,'permission',512)));
    INSERT INTO signer.tx_proxy_proof(tx_id,guild_id,address,player_id,proof_nonce,source_height)
    VALUES((_request->>'id')::integer,_guild_id,_address,COALESCE(_player_id,''),COALESCE(_nonce,0),_context.indexed_height::bigint);
    RETURN _request;
END
$BODY$;

-- Called by the existing signup insert. The actor must actually belong to
-- this guild: the chain derives the destination guild from the signer.
CREATE FUNCTION signer.ENQUEUE_GUILD_PROXY_V022(_guild_id VARCHAR,_address VARCHAR,
    _pubkey VARCHAR,_signature VARCHAR,_flags JSONB) RETURNS JSONB
LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _actor VARCHAR;
BEGIN
    SELECT r.player_id INTO _actor FROM signer.role r JOIN structs.player p ON p.id=r.player_id
    WHERE r.status='ready' AND p.guild_id=_guild_id AND EXISTS (SELECT 1 FROM signer.account a
        WHERE a.role_id=r.id AND a.status IN ('available','signing')
            AND signer.PERMISSION_CHECK(a.address,_guild_id,512)) ORDER BY r.id LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'guild proxy signer is not ready' USING ERRCODE='55000'; END IF;
    RETURN signer.CREATE_PROXY_TRANSACTION_V022(_actor,_guild_id,_address,_pubkey,_signature,_flags);
END
$BODY$;
CREATE OR REPLACE FUNCTION signer.MEMBERSHIP_CONTEXT_CHECK(_tx_id INTEGER,_address CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE
    _tx signer.tx%ROWTYPE; _actor structs.player%ROWTYPE; _target structs.player%ROWTYPE; _guild structs.guild%ROWTYPE;
    _app structs.guild_membership_application%ROWTYPE; _infusion structs.infusion%ROWTYPE; _reactor structs.reactor%ROWTYPE;
    _guild_id CHARACTER VARYING; _target_id CHARACTER VARYING; _station CHARACTER VARYING; _previous_station CHARACTER VARYING;
    _infusions CHARACTER VARYING[]; _id TEXT; _arguments JSONB; _type TEXT; _policy TEXT; _pending BOOLEAN;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.module<>'structs' THEN RETURN FALSE; END IF;
    IF _tx.command='guild-membership-join-proxy' THEN
        RETURN signer.PROXY_CONTEXT_CHECK_V022(_tx_id,_address);
    END IF;
    SELECT p.* INTO _actor FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved' AND pa.player_id=_tx.requested_player_id;
    IF NOT FOUND OR signer.PERMISSION_CHECK(_address,_actor.id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    _station := _tx.flags->>'substation-id';
    CASE _tx.command::text
        WHEN 'guild-membership-invite','guild-membership-kick',
             'guild-membership-request-approve','guild-membership-request-deny' THEN
            _target_id := _tx.args->>0; _guild_id := _tx.flags->>'guild-id';
        WHEN 'guild-membership-invite-approve','guild-membership-invite-deny','guild-membership-request' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.flags->>'player-id';
        WHEN 'guild-membership-invite-revoke','guild-membership-request-revoke' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.args->>1;
        WHEN 'guild-membership-join' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.flags->>'player-id';
            _infusions := string_to_array(_tx.args->>1,',');
        ELSE RETURN FALSE;
    END CASE;
    BEGIN
        _arguments := signer.MEMBERSHIP_ARGUMENTS(_tx.command::text,_guild_id,_target_id,_station,_infusions);
    EXCEPTION WHEN invalid_parameter_value THEN RETURN FALSE; END;
    IF _tx.args IS DISTINCT FROM _arguments->'args' OR _tx.flags IS DISTINCT FROM _arguments->'flags'
        OR _tx.object_id IS DISTINCT FROM _guild_id
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=_tx_id AND check_type='object'
            AND object_id=_actor.id AND permission=512 AND subject_id='' AND operation='') THEN RETURN FALSE; END IF;
    SELECT * INTO _guild FROM structs.guild WHERE id=_guild_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;
    SELECT * INTO _target FROM structs.player WHERE id=_target_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    IF _tx.command='guild-membership-kick' THEN
        RETURN _target.guild_id IS NOT DISTINCT FROM _guild_id AND _guild.owner IS DISTINCT FROM _target.id
            AND signer.PERMISSION_CHECK(_address,_guild_id,512) IS TRUE
            AND (_actor.guild_id IS DISTINCT FROM _guild_id OR
                (_actor.guild_rank IS NOT NULL AND _target.guild_rank IS NOT NULL AND _actor.guild_rank<_target.guild_rank));
    END IF;
    IF _target.guild_id IS NOT DISTINCT FROM _guild_id THEN RETURN FALSE; END IF;
    _type := CASE WHEN _tx.command::text LIKE 'guild-membership-invite%' THEN 'invite'
        WHEN _tx.command='guild-membership-join' THEN 'direct' ELSE 'request' END;
    -- Terminal projection rows are history, not consent: the chain clears them.
    SELECT * INTO _app FROM structs.guild_membership_application
        WHERE guild_id=_guild_id AND player_id=_target_id AND status='proposed';
    _pending := FOUND;
    IF (_pending AND _app.join_type IS DISTINCT FROM _type)
        OR (NOT _pending AND _tx.command NOT IN ('guild-membership-invite','guild-membership-request','guild-membership-join')) THEN
        RETURN FALSE;
    END IF;
    CASE _tx.command::text
        WHEN 'guild-membership-invite','guild-membership-invite-revoke' THEN _policy := _guild.join_infusion_minimum_bypass_by_invite;
        WHEN 'guild-membership-request-approve','guild-membership-request-deny' THEN _policy := _guild.join_infusion_minimum_bypass_by_request;
        ELSE
            IF signer.PERMISSION_CHECK(_address,_target_id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            IF _tx.command='guild-membership-request'
                AND COALESCE(_guild.join_infusion_minimum_bypass_by_request,'') NOT IN ('permissioned','member') THEN RETURN FALSE; END IF;
    END CASE;
    IF _tx.command IN ('guild-membership-invite','guild-membership-invite-revoke',
        'guild-membership-request-approve','guild-membership-request-deny') THEN
        CASE _policy
            WHEN 'permissioned' THEN
                IF signer.PERMISSION_CHECK(_address,_guild_id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            WHEN 'member' THEN
                IF (_actor.guild_id=_guild_id OR _guild.owner=_actor.id) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    _previous_station := COALESCE(NULLIF(_app.substation_id,''),_guild.entry_substation_id);
    IF _tx.command='guild-membership-join'
        AND NOT signer.MEMBERSHIP_STATION_ACCEPTING(_previous_station) THEN RETURN FALSE; END IF;
    IF NULLIF(_station,'') IS NOT NULL AND _station IS DISTINCT FROM COALESCE(_app.substation_id,'') THEN
        IF NOT signer.MEMBERSHIP_STATION_ACCEPTING(_station)
            OR signer.PERMISSION_CHECK(_address,_station,1024) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    END IF;
    IF _tx.command IN ('guild-membership-invite-approve','guild-membership-request-approve','guild-membership-join')
        AND NOT signer.MEMBERSHIP_STATION_ACCEPTING(COALESCE(NULLIF(_station,''),_previous_station)) THEN RETURN FALSE; END IF;

    IF _tx.command='guild-membership-join' THEN
        IF _guild.join_infusion_minimum_p IS NULL OR _guild.join_infusion_minimum_p NOT BETWEEN 0 AND 18446744073709551615
            OR _guild.join_infusion_minimum_p<>trunc(_guild.join_infusion_minimum_p)
            OR NOT EXISTS (SELECT 1 FROM structs.reactor WHERE id=_guild.primary_reactor_id) THEN RETURN FALSE; END IF;
        IF _guild.join_infusion_minimum_p>0 THEN
            FOREACH _id IN ARRAY COALESCE(_infusions,ARRAY[]::varchar[]) LOOP
                SELECT * INTO _infusion FROM structs.infusion
                    WHERE destination_id=split_part(_id,'-',1)||'-'||split_part(_id,'-',2) AND address=split_part(_id,'-',3);
                IF NOT FOUND OR _infusion.destination_type IS DISTINCT FROM 'reactor' OR _infusion.player_id IS DISTINCT FROM _target_id
                    OR NOT EXISTS (SELECT 1 FROM structs.asset_owner WHERE address=_infusion.address AND owner_id=_target_id) THEN RETURN FALSE; END IF;
                SELECT * INTO _reactor FROM structs.reactor WHERE id=_infusion.destination_id;
                IF NOT FOUND THEN RETURN FALSE; END IF;
                IF _reactor.guild_id IS DISTINCT FROM _guild_id AND _reactor.id IS DISTINCT FROM _guild.primary_reactor_id
                    AND signer.PERMISSION_CHECK(_address,_target_id,64) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            END LOOP;
        END IF;
    END IF;
    RETURN TRUE;
END
$BODY$;
    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_JOIN_PROXY()
        RETURNS trigger AS
    $BODY$
    DECLARE
        ugc JSONB;
    BEGIN
        ugc := '{}'::JSONB;

        IF NEW.username <> '' AND NEW.username IS NOT NULL THEN
            ugc := jsonb_build_object('player-name', NEW.username);
        END IF;

        IF NEW.pfp <> '' AND NEW.pfp IS NOT NULL THEN
            ugc := ugc || jsonb_build_object('player-pfp', NEW.pfp);
        END IF;

        IF NEW.pfp_client_render_attributes IS NOT NULL THEN
            ugc := ugc || jsonb_build_object('player-pfp-client-render-attributes', NEW.pfp_client_render_attributes::text);
        END IF;

        PERFORM signer.ENQUEUE_GUILD_PROXY_V022(NEW.guild_id,NEW.primary_address,NEW.pubkey,NEW.signature,ugc);

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp COST 100;

REVOKE ALL ON TABLE signer.tx_proxy_proof FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.CREATE_PROXY_TRANSACTION_V022(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,JSONB),
    signer.ENQUEUE_GUILD_PROXY_V022(VARCHAR,VARCHAR,VARCHAR,VARCHAR,JSONB) FROM PUBLIC;
COMMIT;
