-- Deploy structs-pg:table-signer-tx to pg

BEGIN;

    CREATE TYPE structs.signer_tx_status AS ENUM(
        'pending',
        'claimed',
        'broadcast',
        'error'
    );

    CREATE TYPE structs.signer_tx_module AS ENUM(
        'structs',
        'bank',
        'staking',
        'auth',
        'authz'
    );

    CREATE TYPE structs.signer_tx_type AS ENUM (
        'address-register',
        'address-revoke',
        'allocation-create',
        'allocation-delete',
        'allocation-transfer',
        'allocation-update',
        'fleet-move',
        'guild-bank-redeem',
        'guild-create',
        'guild-membership',
        'guild-membership-invite',
        'guild-membership-invite-approve',
        'guild-membership-invite-deny',
        'guild-membership-join',
        'guild-membership-join-proxy',
        'guild-membership-kick',
        'guild-membership-request',
        'guild-membership-request-approve',
        'guild-membership-request-deny',
        'guild-membership-request-revoke',
        'guild-update-endpoint',
        'guild-update-entry-substation-id',
        'guild-update-join-infusion-minimum',
        'guild-update-join-infusion-minimum-by-invite',
        'guild-update-join-infusion-minimum-by-request',
        'guild-update-owner-id',
        'permission-grant-on-address',
        'permission-grant-on-object',
        'permission-revoke-on-address',
        'permission-revoke-on-object',
        'permission-set-on-address',
        'permission-set-on-object',
        'planet-explore',
        'planet-raid-complete',
        'planet-raid-compute',
        'player-update-primary-address',
        'struct-activate',
        'struct-attack',
        'struct-build-complete',
        'struct-build-compute',
        'struct-build-initiate',
        'struct-deactivate',
        'struct-defense-clear',
        'struct-defense-set',
        'struct-generator-infuse',
        'struct-mine-compute',
        'struct-move',
        'struct-ore-mine-complete',
        'struct-ore-refine-complete',
        'struct-refine-compute',
        'struct-stealth-activate',
        'struct-stealth-deactivate',
        'substation-allocation-connect',
        'substation-allocation-disconnect',
        'substation-create',
        'substation-delete',
        'substation-player-connect',
        'substation-player-disconnect',
        'substation-player-migrate',
        'send',
        'delegate'
    );


    CREATE TABLE signer.tx (
        id SERIAL PRIMARY KEY,
        object_id CHARACTER VARYING,
        permission_requirement INTEGER,
        priority INTEGER DEFAULT 10,
        account_id INTEGER,
        module structs.signer_tx_module NOT NULL,
        command structs.signer_tx_type NOT NULL,
        args JSONB,
        flags JSONB,
        status structs.signer_tx_status DEFAULT 'pending',
        output TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE OR REPLACE FUNCTION signer.CREATE_TRANSACTION(
        _object_id CHARACTER VARYING,
        _permission_requirement INTEGER,
        _module structs.signer_tx_module,
        _command structs.signer_tx_type,
        _args JSONB,
        _flags JSONB
    ) RETURNS JSONB AS
    $BODY$
    DECLARE
        new_transaction RECORD;
    BEGIN
        INSERT INTO signer.tx(object_id, permission_requirement, module, command,  args, flags)
            VALUES(_object_id, _permission_requirement, _module, _command, _args, _flags)
            RETURNING * INTO new_transaction;

        RETURN to_jsonb(new_transaction);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.CLAIM_INTERNAL_TRANSACTION() RETURNS JSONB AS
    $BODY$
    DECLARE
        claimed_tx RECORD;
    BEGIN

        WITH base_role AS (
            SELECT
                account.address as address,
                permission.val as permission,
                permission.player_id as object_id
            FROM
                signer.account,
                structs.permission
            WHERE account.address = permission.object_index
        ), object_owners AS (
            SELECT
                base_role.address as address,
                base_role.permission as permission,
                player_object.object_id as object_id
            FROM
                structs.player_object, base_role
            WHERE player_object.player_id = base_role.object_id
        ), address_permission AS (
            SELECT
              base_role.address as address,
              base_role.permission & permission.val as permission,
              permission.object_id as object_id
            FROM structs.permission, base_role
            WHERE permission.player_id = base_role.object_id
            UNION
            SELECT * FROM object_owners
            UNION
            SELECT * FROM base_role
          ), pending_transaction AS MATERIALIZED (
                SELECT *
                FROM signer.tx
                WHERE
                        status = 'pending'
                  AND  object_id IN (SELECT address_permission.object_id
                                          FROM address_permission
                                          WHERE (address_permission.permission & tx.permission_requirement) > 0)
                ORDER BY updated_at ASC
                LIMIT 1 FOR UPDATE SKIP LOCKED
            )
            UPDATE signer.tx
            SET status     = 'claimed',
                -- account_id = <>,
                updated_at = NOW()
            WHERE id = ANY (SELECT id FROM pending_transaction)
            RETURNING * INTO claimed_tx;

        RETURN to_jsonb(claimed_tx);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.TRANSACTION_ERROR(transaction_id INTEGER, transaction_error TEXT) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.tx
        SET status      = 'error',
            output      = transaction_error,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.TRANSACTION_BROADCAST_RESULTS(transaction_id INTEGER, transaction_output TEXT) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.tx
        SET status      = 'broadcast',
            output      = transaction_output,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;



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



    CREATE OR REPLACE FUNCTION signer.tx_infuse(
        _player_id CHARACTER VARYING,
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
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'staking','delegate',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        ELSIF _real_destination ILIKE '5-%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','struct-generator-infuse ',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        END IF;

        RETURN;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;



    CREATE OR REPLACE FUNCTION signer.tx_substation_create(
        _player_id CHARACTER VARYING,
        _allocation_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','substation-create',jsonb_build_array(_player_id, _allocation_id),'{}');
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
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-player-connect',jsonb_build_array(_substation_id, _target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(
        _player_id CHARACTER VARYING,
        _target_player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','substation-player-disconnect',jsonb_build_array(_target_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_explore(
        _player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','planet-explore',jsonb_build_array(_player_id),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_build_initiate(
        _player_id CHARACTER VARYING,
        _struct_type_id INTEGER,
        _operate_ambit CHARACTER VARYING,
        _slot INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-initiate',jsonb_build_array(_player_id, _struct_type_id, _operate_ambit,_slot ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_build_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_activate(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-activate',jsonb_build_array(_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_struct_deactivate(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-deactivate',jsonb_build_array(_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_ore_mine_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-ore-mine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_ore_refine_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-ore-refine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_attack(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _target_struct_id CHARACTER VARYING,
        _weapon_system CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-attack',jsonb_build_array(_struct_id, _target_struct_id, _weapon_system ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;



    CREATE OR REPLACE FUNCTION signer.tx_struct_defense_set(
        _player_id CHARACTER VARYING,
        _defender_struct_id CHARACTER VARYING,
        _protected_struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-defense-set',jsonb_build_array(_defender_struct_id, _protected_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_defense_clear(
        _player_id CHARACTER VARYING,
        _defender_struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-defense-clear',jsonb_build_array(_defender_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_activate(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-stealth-activate',jsonb_build_array(_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_deactivate(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-stealth-deactivate',jsonb_build_array(_struct_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_fleet_move(
        _player_id CHARACTER VARYING,
        _fleet_id CHARACTER VARYING,
        _destination_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','fleet-move',jsonb_build_array(_fleet_id, _destination_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;



    CREATE OR REPLACE FUNCTION signer.tx_planet_raid_complete(
        _player_id CHARACTER VARYING,
        _fleet_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','planet-raid-complete',jsonb_build_array(_fleet_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;



    CREATE OR REPLACE FUNCTION signer.tx_player_resume(
        _player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','player-resume',jsonb_build_array(_player_id ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
