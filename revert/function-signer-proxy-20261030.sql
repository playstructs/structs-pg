-- Revert structs-pg:function-signer-proxy-20261030 from pg
BEGIN;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM signer.tx_proxy_proof) THEN
    RAISE EXCEPTION 'preserve proxy submission history before reverting'; END IF; END $$;
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
            ugc := ugc || jsonb_build_object('player-pfp-cr-attributes', NEW.pfp_client_render_attributes::text);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            NEW.guild_id,
            512,
            'structs',
            'guild-membership-join-proxy',
            jsonb_build_array(NEW.primary_address, NEW.pubkey, NEW.signature),
            ugc
        );

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

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
DROP FUNCTION signer.ENQUEUE_GUILD_PROXY_V022(VARCHAR,VARCHAR,VARCHAR,VARCHAR,JSONB);
DROP FUNCTION signer.CREATE_PROXY_TRANSACTION_V022(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,JSONB);
DROP FUNCTION signer.PROXY_CONTEXT_CHECK_V022(INTEGER,VARCHAR);
DROP TABLE signer.tx_proxy_proof;
COMMIT;
