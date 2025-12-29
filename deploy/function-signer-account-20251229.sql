-- Deploy structs-pg:function-signer-account-20251229 to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.UPDATE_PENDING_ACCOUNT(_account_id INTEGER, _player_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING, _permission INTEGER) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;

        -- [address] [proof pubkey] [proof signature] [permissions]
        -- TODO should check the highest perms it has and use that instead
        INSERT INTO signer.tx (object_id, module, command, args, permission_requirement )
            VALUES (_player_id, 'structs', 'address-register', jsonb_build_array(_player_id, _address , _pubkey ,_signature , _permission), 255);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;

COMMIT;

