-- Deploy structs-pg:function-signer-tx-play to pg

BEGIN;

    CREATE OR REPLACE FUNCTION signer.tx_explore(
        _player_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','planet-explore',jsonb_build_array(_player_id),'{}');
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

    CREATE OR REPLACE FUNCTION signer.tx_struct_build_cancel(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-cancel',jsonb_build_array(_struct_id),'{}');
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

    CREATE OR REPLACE FUNCTION signer.tx_struct_move(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _location_type CHARACTER VARYING,
        _ambit CHARACTER VARYING,
        _slot INTEGER
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-move',jsonb_build_array(_struct_id, _location_type, _ambit, _slot),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;

