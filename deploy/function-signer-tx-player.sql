-- Deploy structs-pg:function-signer-tx-player to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.tx_player_resume(
        _player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','player-resume',jsonb_build_array(_player_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_player_update_primary_address(
        _player_id CHARACTER VARYING,
        _primary_address CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2,'structs','player-update-primary-address',jsonb_build_array( _player_id, _primary_address),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_address_register(
        _player_id CHARACTER VARYING,
        _address_to_register CHARACTER VARYING,
        _proof_pub_key CHARACTER VARYING,
        _proof_signature CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','address-register',jsonb_build_array(_player_id, _address_to_register, _proof_pub_key, _proof_signature, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_address_revoke(
        _player_id CHARACTER VARYING,
        _address_to_revoke CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','address-revoke',jsonb_build_array(_player_id, _address_to_revoke),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

