-- Deploy structs-pg:function-signer-tx-bank to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.tx_bank_send(
        _player_id CHARACTER VARYING,
        _amount NUMERIC,
        _denom CHARACTER VARYING,
        _destination_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    DECLARE
        _primary_address_sender CHARACTER VARYING;
        _primary_address_recipient CHARACTER VARYING;

        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN

        SELECT player.primary_address INTO _primary_address_sender FROM structs.player where player.id = _player_id;
        SELECT player.primary_address INTO _primary_address_recipient FROM structs.player where player.id = _destination_player_id;

        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'bank','send',jsonb_build_array(_primary_address_sender,_primary_address_recipient, _real_amount || _real_denom),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

