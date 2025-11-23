-- Deploy structs-pg:function-signer-tx-energy to pg

BEGIN;

    --signer.tx_provider_create(player_id, substation_id, rate_denom, rate_amount, access_policy, provider_penalty, consumer_penalty, capacity_min, capacity_max, duration_min, duration_max)
    CREATE OR REPLACE FUNCTION signer.tx_provider_create(
        _player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _rate_denom CHARACTER VARYING,
        _rate_amount NUMERIC,
        _access_policy CHARACTER VARYING,
        _provider_penalty NUMERIC,
        _consumer_penalty NUMERIC,
        _capacity_min NUMERIC,
        _capacity_max NUMERIC,
        _duration_min NUMERIC,
        _duration_max NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,8,'structs','provider-create',jsonb_build_array(_substation_id, _rate_amount || _rate_denom, _access_policy, _provider_penalty, _consumer_penalty, _capacity_min, _capacity_max, _duration_min, _duration_max),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_withdraw_balance(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _destination_address CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,8,'structs','provider-withdraw-balance',jsonb_build_array(_provider_id, _destination_address),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_minimum(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _new_minimum_capacity NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-capacity-minimum',jsonb_build_array(_provider_id, _new_minimum_capacity),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_maximum(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _new_maximum_capacity NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-capacity-maximum',jsonb_build_array(_provider_id, _new_maximum_capacity),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_minimum(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _new_minimum_duration NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-duration-minimum',jsonb_build_array( _provider_id, _new_minimum_duration),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_maximum(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _new_maximum_duration NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-duration-maximum',jsonb_build_array( _provider_id, _new_maximum_duration),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_access_policy(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _access_policy CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-access-policy',jsonb_build_array( _provider_id, _access_policy),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_guild_grant(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _guild_ids CHARACTER VARYING[]
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-guild-grant',jsonb_build_array( _provider_id, _guild_ids),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_guild_revoke(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _guild_ids CHARACTER VARYING[]
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-guild-revoke',jsonb_build_array( _provider_id, _guild_ids),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_delete(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-delete',jsonb_build_array( _provider_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    --signer.tx_agreement_create(player_id, provider_id, duration, capacity)
    CREATE OR REPLACE FUNCTION signer.tx_agreement_open(
        _player_id CHARACTER VARYING,
        _provider_id CHARACTER VARYING,
        _duration NUMERIC,
        _capacity NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-open',jsonb_build_array(_provider_id, _duration, _capacity),'{}');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_close(
        _player_id CHARACTER VARYING,
        _agreement_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-close',jsonb_build_array( _agreement_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_increase(
        _player_id CHARACTER VARYING,
        _agreement_id CHARACTER VARYING,
        _capacity_increase NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-capacity-increase',jsonb_build_array( _agreement_id, _capacity_increase),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_decrease(
        _player_id CHARACTER VARYING,
        _agreement_id CHARACTER VARYING,
        _capacity_decrease NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-capacity-decrease',jsonb_build_array( _agreement_id, _capacity_decrease),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_duration_increase(
        _player_id CHARACTER VARYING,
        _agreement_id CHARACTER VARYING,
        _duration_increase NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-duration-increase',jsonb_build_array( _agreement_id, _duration_increase),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    --signer.tx_substation_allocation_connect(player_id, allocation_id, substation_id)
    CREATE OR REPLACE FUNCTION signer.tx_allocation_connect(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-allocation-connect',jsonb_build_array(_allocation_id, _substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_allocation_disconnect(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-allocation-disconnect',jsonb_build_array(_allocation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_transfer(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING,
        _controller CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-transfer',jsonb_build_array(_allocation_id, _controller),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    --[playerId, source, amount, destinationId]
    CREATE OR REPLACE FUNCTION signer.tx_allocation_create(
        _allocation_type CHARACTER VARYING,
        _source_id  CHARACTER VARYING,
        _amount  NUMERIC,
        _controller CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    DECLARE
            _flags JSONB;
    BEGIN

        IF _controller IS NOT NULL AND _controller <> '' THEN
            _flags := json_build_object('controller', _controller, 'type', _allocation_type);
        ELSE
            _flags := json_build_object('type', _allocation_type);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_source_id,8,'structs','allocation-create',jsonb_build_array(_source_id, _amount),_flags);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_delete(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-delete',jsonb_build_array(_allocation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_update(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING,
        _power NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-update',jsonb_build_array(_allocation_id, _power),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_create(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','substation-create',jsonb_build_array(_allocation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_player_connect(
        _player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-connect',jsonb_build_array(_substation_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(
        _substation_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-disconnect',jsonb_build_array(_target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_delete(
        _player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _migration_substation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-delete',jsonb_build_array( _substation_id, _migration_substation_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_player_migrate(
        _player_id CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _target_player_ids CHARACTER VARYING[]
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-migrate',jsonb_build_array( _substation_id, _target_player_ids),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_infuse(
        _player_id CHARACTER VARYING,
        _delegator_address CHARACTER VARYING,
        _destination CHARACTER VARYING,
        _amount NUMERIC,
        _denom CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;

        _real_destination CHARACTER VARYING;
    BEGIN

        IF _denom = 'ualpha' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSIF _denom = 'alpha' THEN
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        ELSE
            -- Not an acceptable denom
            RETURN;
        END IF;


        -- guild   = 0;
        -- reactor = 3;
        -- struct  = 5;
        -- structsvaloper

        -- Guild ID
            -- Lookup Reactor ID
        IF _destination ILIKE '0-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id IN (SELECT guild.primary_reactor_id FROM structs.guild WHERE guild.id = _destination);

        -- Reactor ID
        ELSIF _destination ILIKE '3-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id = _destination;

        -- Struct ID
        ELSIF _destination ILIKE '5-%' THEN
            -- TODO Make sure it's a generator
            _real_destination := _destination;

        -- Reactor
        ELSIF _destination ILIKE 'structsvaloper%' THEN
            _real_destination := _destination;
        ELSE
            RETURN;
        END IF;

        IF _real_destination ILIKE 'structsvaloper%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-infuse',jsonb_build_array(_delegator_address, _real_destination, _real_amount || _real_denom),'{}');
        ELSIF _real_destination ILIKE '5-%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','struct-generator-infuse ',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        END IF;

        RETURN;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_reactor_begin_migration(
        _player_id CHARACTER VARYING,
        _delegator_address CHARACTER VARYING,
        _validator_src_address CHARACTER VARYING,
        _validator_dst_address CHARACTER VARYING,
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
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-begin-migration',jsonb_build_array( _delegator_address, _validator_src_address, _validator_dst_address, _real_amount || _real_denom),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_defuse(
        _player_id CHARACTER VARYING,
        _delegator_address CHARACTER VARYING,
        _validator_address CHARACTER VARYING,
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
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-defuse',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_cancel_defusion(
        _player_id CHARACTER VARYING,
        _delegator_address CHARACTER VARYING,
        _validator_address CHARACTER VARYING,
        _amount NUMERIC,
        _denom CHARACTER VARYING,
        _creation_height INTEGER
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
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-cancel-defusion',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom, _creation_height),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

