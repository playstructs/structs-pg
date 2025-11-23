-- Deploy structs-pg:function-signer-tx-permissions to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_object(
        _player_id CHARACTER VARYING,
        _object_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-grant-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_address(
        _player_id CHARACTER VARYING,
        _address CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-grant-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_object(
        _player_id CHARACTER VARYING,
        _object_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-revoke-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_address(
        _player_id CHARACTER VARYING,
        _address CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-revoke-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_object(
        _player_id CHARACTER VARYING,
        _object_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-set-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_address(
        _player_id CHARACTER VARYING,
        _address CHARACTER VARYING,
        _permissions INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-set-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

