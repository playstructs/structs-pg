-- Revert structs-pg:function-signer-tx-20260325-permission-overhaul from pg
--
-- Restores all signer.tx_ functions to their pre-110b state with old 8-bit permission values.

BEGIN;

    -- Restore provider functions with old permission values
    CREATE OR REPLACE FUNCTION signer.tx_provider_create(
        _player_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _rate_denom CHARACTER VARYING,
        _rate_amount NUMERIC, _access_policy CHARACTER VARYING, _provider_penalty NUMERIC,
        _consumer_penalty NUMERIC, _capacity_min NUMERIC, _capacity_max NUMERIC,
        _duration_min NUMERIC, _duration_max NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,8,'structs','provider-create',jsonb_build_array(_substation_id, _rate_amount || _rate_denom, _access_policy, _provider_penalty, _consumer_penalty, _capacity_min, _capacity_max, _duration_min, _duration_max),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_withdraw_balance(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _destination_address CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,8,'structs','provider-withdraw-balance',jsonb_build_array(_provider_id, _destination_address),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_minimum(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _new_minimum_capacity NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-capacity-minimum',jsonb_build_array(_provider_id, _new_minimum_capacity),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_maximum(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _new_maximum_capacity NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-capacity-maximum',jsonb_build_array(_provider_id, _new_maximum_capacity),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_minimum(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _new_minimum_duration NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-duration-minimum',jsonb_build_array( _provider_id, _new_minimum_duration),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_maximum(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _new_maximum_duration NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-duration-maximum',jsonb_build_array( _provider_id, _new_maximum_duration),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_update_access_policy(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _access_policy CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-update-access-policy',jsonb_build_array( _provider_id, _access_policy),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_delete(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-delete',jsonb_build_array( _provider_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore removed provider guild functions
    CREATE OR REPLACE FUNCTION signer.tx_provider_guild_grant(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _guild_ids CHARACTER VARYING[]
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-guild-grant',jsonb_build_array( _provider_id, _guild_ids),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_provider_guild_revoke(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _guild_ids CHARACTER VARYING[]
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,2,'structs','provider-guild-revoke',jsonb_build_array( _provider_id, _guild_ids),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore agreement functions
    CREATE OR REPLACE FUNCTION signer.tx_agreement_open(
        _player_id CHARACTER VARYING, _provider_id CHARACTER VARYING, _duration NUMERIC, _capacity NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-open',jsonb_build_array(_provider_id, _duration, _capacity),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_close(
        _player_id CHARACTER VARYING, _agreement_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-close',jsonb_build_array( _agreement_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_increase(
        _player_id CHARACTER VARYING, _agreement_id CHARACTER VARYING, _capacity_increase NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-capacity-increase',jsonb_build_array( _agreement_id, _capacity_increase),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_decrease(
        _player_id CHARACTER VARYING, _agreement_id CHARACTER VARYING, _capacity_decrease NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-capacity-decrease',jsonb_build_array( _agreement_id, _capacity_decrease),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_agreement_duration_increase(
        _player_id CHARACTER VARYING, _agreement_id CHARACTER VARYING, _duration_increase NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','agreement-duration-increase',jsonb_build_array( _agreement_id, _duration_increase),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore allocation functions
    CREATE OR REPLACE FUNCTION signer.tx_allocation_connect(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING, _substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-allocation-connect',jsonb_build_array(_allocation_id, _substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_disconnect(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-allocation-disconnect',jsonb_build_array(_allocation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_transfer(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING, _controller CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-transfer',jsonb_build_array(_allocation_id, _controller),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_create(
        _allocation_type CHARACTER VARYING, _source_id CHARACTER VARYING, _amount NUMERIC, _controller CHARACTER VARYING
    ) RETURNS void AS $BODY$
    DECLARE _flags JSONB;
    BEGIN
        IF _controller IS NOT NULL AND _controller <> '' THEN
            _flags := json_build_object('controller', _controller, 'type', _allocation_type);
        ELSE
            _flags := json_build_object('type', _allocation_type);
        END IF;
        PERFORM signer.CREATE_TRANSACTION(_source_id,8,'structs','allocation-create',jsonb_build_array(_source_id, _amount),_flags);
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_delete(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-delete',jsonb_build_array(_allocation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_allocation_update(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING, _power NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-update',jsonb_build_array(_allocation_id, _power),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore substation functions
    CREATE OR REPLACE FUNCTION signer.tx_substation_create(
        _player_id CHARACTER VARYING, _allocation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','substation-create',jsonb_build_array(_allocation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_player_connect(
        _player_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-connect',jsonb_build_array(_substation_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_substation_player_disconnect(character varying,character varying);
    CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(
        _substation_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-disconnect',jsonb_build_array(_target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_delete(
        _player_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _migration_substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-delete',jsonb_build_array( _substation_id, _migration_substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_player_migrate(
        _player_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _target_player_ids CHARACTER VARYING[]
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,32,'structs','substation-player-migrate',jsonb_build_array( _substation_id, _target_player_ids),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore infuse with old permission and trailing space bug
    CREATE OR REPLACE FUNCTION signer.tx_infuse(
        _player_id CHARACTER VARYING, _delegator_address CHARACTER VARYING, _destination CHARACTER VARYING,
        _amount NUMERIC, _denom CHARACTER VARYING
    ) RETURNS void AS $BODY$
    DECLARE _real_denom CHARACTER VARYING; _real_amount NUMERIC; _real_destination CHARACTER VARYING;
    BEGIN
        IF _denom = 'ualpha' THEN _real_denom := _denom; _real_amount := _amount;
        ELSIF _denom = 'alpha' THEN _real_denom := 'u' || _denom; _real_amount := _amount * 10^6;
        ELSE RETURN; END IF;
        IF _destination ILIKE '0-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id IN (SELECT guild.primary_reactor_id FROM structs.guild WHERE guild.id = _destination);
        ELSIF _destination ILIKE '3-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id = _destination;
        ELSIF _destination ILIKE '5-%' THEN _real_destination := _destination;
        ELSIF _destination ILIKE 'structsvaloper%' THEN _real_destination := _destination;
        ELSE RETURN; END IF;
        IF _real_destination ILIKE 'structsvaloper%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-infuse',jsonb_build_array(_delegator_address, _real_destination, _real_amount || _real_denom),'{}');
        ELSIF _real_destination ILIKE '5-%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','struct-generator-infuse ',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        END IF;
        RETURN;
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_begin_migration(
        _player_id CHARACTER VARYING, _delegator_address CHARACTER VARYING,
        _validator_src_address CHARACTER VARYING, _validator_dst_address CHARACTER VARYING,
        _amount NUMERIC, _denom CHARACTER VARYING
    ) RETURNS void AS $BODY$
    DECLARE _real_denom CHARACTER VARYING; _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN _real_denom := _denom; _real_amount := _amount;
        ELSE _real_denom := 'u' || _denom; _real_amount := _amount * 10^6; END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-begin-migration',jsonb_build_array( _delegator_address, _validator_src_address, _validator_dst_address, _real_amount || _real_denom),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_defuse(
        _player_id CHARACTER VARYING, _delegator_address CHARACTER VARYING,
        _validator_address CHARACTER VARYING, _amount NUMERIC, _denom CHARACTER VARYING
    ) RETURNS void AS $BODY$
    DECLARE _real_denom CHARACTER VARYING; _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN _real_denom := _denom; _real_amount := _amount;
        ELSE _real_denom := 'u' || _denom; _real_amount := _amount * 10^6; END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-defuse',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_cancel_defusion(
        _player_id CHARACTER VARYING, _delegator_address CHARACTER VARYING,
        _validator_address CHARACTER VARYING, _amount NUMERIC, _denom CHARACTER VARYING, _creation_height INTEGER
    ) RETURNS void AS $BODY$
    DECLARE _real_denom CHARACTER VARYING; _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN _real_denom := _denom; _real_amount := _amount;
        ELSE _real_denom := 'u' || _denom; _real_amount := _amount * 10^6; END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','reactor-cancel-defusion',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom, _creation_height),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore guild functions
    DROP FUNCTION IF EXISTS signer.tx_guild_create(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_redeem(
        _player_id CHARACTER VARYING, _amount NUMERIC, _denom CHARACTER VARYING
    ) RETURNS void AS $BODY$
    DECLARE _real_denom CHARACTER VARYING; _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN _real_denom := _denom; _real_amount := _amount;
        ELSE _real_denom := 'u' || _denom; _real_amount := _amount * 10^6; END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-redeem',jsonb_build_array(_real_amount || _real_denom),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_mint(
        _player_id CHARACTER VARYING, _amount_alpha NUMERIC, _amount_token NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-mint',jsonb_build_array( _amount_alpha, _amount_token),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_confiscate_and_burn(
        _player_id CHARACTER VARYING, _address CHARACTER VARYING, _amount_token NUMERIC
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','guild-bank-confiscate-and-burn',jsonb_build_array(_address, _amount_token),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_substation_id(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _entry_substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,2,'structs','guild-update-entry-substation-id',jsonb_build_array( _guild_id, _entry_substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_update_entry_rank(CHARACTER VARYING, BIGINT);

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING, _substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_approve(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING, _substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_deny(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_revoke(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-invite-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_join(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _infusion_id CHARACTER VARYING[]
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-join',jsonb_build_array(_guild_id, _player_id, _substation_id, _infusion_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_kick(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-kick',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-request',jsonb_build_array( _guild_id, _player_id, _substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_approve(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING, _substation_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-request-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_deny(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16,'structs','guild-membership-request-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_revoke(
        _player_id CHARACTER VARYING, _guild_id CHARACTER VARYING, _target_player_id CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-membership-request-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Restore player functions
    CREATE OR REPLACE FUNCTION signer.tx_player_update_primary_address(
        _player_id CHARACTER VARYING, _primary_address CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2,'structs','player-update-primary-address',jsonb_build_array( _player_id, _primary_address),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_address_register(
        _player_id CHARACTER VARYING, _address_to_register CHARACTER VARYING,
        _proof_pub_key CHARACTER VARYING, _proof_signature CHARACTER VARYING, _permissions INTEGER
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','address-register',jsonb_build_array(_player_id, _address_to_register, _proof_pub_key, _proof_signature, _permissions),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_address_revoke(
        _player_id CHARACTER VARYING, _address_to_revoke CHARACTER VARYING
    ) RETURNS void AS $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','address-revoke',jsonb_build_array(_player_id, _address_to_revoke),'{}');
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Drop new functions that didn't exist before
    DROP FUNCTION IF EXISTS signer.tx_permission_guild_rank_set(CHARACTER VARYING, CHARACTER VARYING, BIGINT, BIGINT);
    DROP FUNCTION IF EXISTS signer.tx_permission_guild_rank_revoke(CHARACTER VARYING, CHARACTER VARYING, BIGINT);
    DROP FUNCTION IF EXISTS signer.tx_player_update_guild_rank(CHARACTER VARYING, BIGINT);
    DROP FUNCTION IF EXISTS signer.tx_player_send(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, NUMERIC, CHARACTER VARYING);

    -- Restore CLAIM functions with HasOneOf (> 0)
    CREATE OR REPLACE FUNCTION signer.CLAIM_INTERNAL_TRANSACTION() RETURNS JSONB AS
    $BODY$
    DECLARE claimed_tx RECORD;
    BEGIN
        WITH base_role AS (
            SELECT account.address as address, permission.val as permission, permission.player_id as object_id
            FROM signer.account, structs.permission
            WHERE account.address = permission.object_index
        ), object_owners AS (
            SELECT base_role.address as address, base_role.permission as permission, player_object.object_id as object_id
            FROM structs.player_object, base_role
            WHERE player_object.player_id = base_role.object_id
        ), address_permission AS (
            SELECT base_role.address as address, base_role.permission & permission.val as permission, permission.object_id as object_id
            FROM structs.permission, base_role WHERE permission.player_id = base_role.object_id
            UNION SELECT * FROM object_owners
            UNION SELECT * FROM base_role
        ), pending_transaction AS MATERIALIZED (
            SELECT * FROM signer.tx
            WHERE status = 'pending'
              AND object_id IN (SELECT address_permission.object_id FROM address_permission
                                WHERE (address_permission.permission & tx.permission_requirement) > 0)
            ORDER BY updated_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.tx SET status = 'claimed', updated_at = NOW()
        WHERE id = ANY (SELECT id FROM pending_transaction)
        RETURNING * INTO claimed_tx;
        RETURN to_jsonb(claimed_tx);
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;

    CREATE OR REPLACE FUNCTION signer.CLAIM_INTERNAL_ACCOUNT(tx_id INTEGER) RETURNS json AS
    $BODY$
    DECLARE claimed_account RECORD; tx_object_id CHARACTER VARYING; tx_permission_requirement INTEGER;
    BEGIN
        SELECT object_id, permission_requirement INTO tx_object_id, tx_permission_requirement FROM signer.tx WHERE tx.id = tx_id;
        WITH base_role AS (
            SELECT account.address as address, permission.val as permission, permission.player_id as object_id
            FROM signer.account, structs.permission WHERE account.address = permission.object_index
        ), object_owners AS (
            SELECT base_role.address as address, base_role.permission as permission, player_object.object_id as object_id
            FROM structs.player_object, base_role WHERE player_object.player_id = base_role.object_id
        ), address_permission AS (
            SELECT * FROM (
                SELECT base_role.address as address, base_role.permission & permission.val as permission, permission.object_id as object_id
                FROM structs.permission, base_role WHERE permission.player_id = base_role.object_id
                UNION SELECT * FROM object_owners
                UNION SELECT * FROM base_role
            ) WHERE object_id = tx_object_id AND (permission & tx_permission_requirement) > 0
        ), pending_account AS MATERIALIZED (
            SELECT * FROM signer.account
            WHERE account.status = 'available' AND account.address IN (SELECT address_permission.address FROM address_permission)
            ORDER BY account.updated_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.account SET status = 'signing', updated_at = NOW()
        WHERE id = ANY (SELECT id FROM pending_account)
        RETURNING * INTO claimed_account;
        IF claimed_account IS NOT NULL THEN UPDATE signer.tx SET account_id = claimed_account.id WHERE id=tx_id; END IF;
        IF claimed_account IS NULL THEN
            IF (SELECT COUNT(1) FROM signer.account WHERE account.role_id in (select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) > 0)) AND status in ('stub','generating','pending')) = 0 THEN
                INSERT INTO signer.account (role_id, status, created_at, updated_at)
                    VALUES((select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) > 0) LIMIT 1), 'stub', NOW(), NOW())
                        RETURNING * INTO claimed_account;
            END IF;
        END IF;
        RETURN to_json(claimed_account);
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;

    -- Restore UPDATE_PENDING_ACCOUNT with old PermAll=255
    CREATE OR REPLACE FUNCTION signer.UPDATE_PENDING_ACCOUNT(_account_id INTEGER, _player_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING, _permission INTEGER) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;
        INSERT INTO signer.tx (object_id, module, command, args, permission_requirement )
            VALUES (_player_id, 'structs', 'address-register', jsonb_build_array(_player_id, _address , _pubkey ,_signature , _permission), 255);
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;

    -- Restore PLAYER_PENDING_JOIN_PROXY with old PermAssociations=16
    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_JOIN_PROXY()
        RETURNS trigger AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(NEW.guild_id,16,'structs','guild-membership-join-proxy',jsonb_build_array(NEW.primary_address,NEW.pubkey,NEW.signature),'{}');
        RETURN NEW;
    END $BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
