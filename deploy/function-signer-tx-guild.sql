-- Deploy structs-pg:function-signer-tx-guild to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_redeem(
        _player_id CHARACTER VARYING,
        _amount NUMERIC,
        _denom CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN

        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-redeem',jsonb_build_array(_real_amount || _real_denom),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_mint(
        _player_id CHARACTER VARYING,
        _amount_alpha NUMERIC,
        _amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-mint',jsonb_build_array( _amount_alpha, _amount_token),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_confiscate_and_burn(
        _player_id CHARACTER VARYING,
        _address CHARACTER VARYING,
        _amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-confiscate-and-burn',jsonb_build_array(_address, _amount_token),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_substation_id(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _entry_substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,2,'structs','guild-update-entry-substation-id',jsonb_build_array( _guild_id, _entry_substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_approve(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_deny(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_revoke(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_join(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _infusion_id CHARACTER VARYING[]
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-join',jsonb_build_array(_guild_id, _player_id, _substation_id, _infusion_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_kick(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-kick',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-request',jsonb_build_array( _guild_id, _player_id, _substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_approve(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-request-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_deny(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-request-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_revoke(
        _player_id CHARACTER VARYING,
        _guild_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-request-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

