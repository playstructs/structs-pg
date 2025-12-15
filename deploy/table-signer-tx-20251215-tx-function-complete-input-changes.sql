-- Deploy structs-pg:table-signer-tx-20251215-tx-function-complete-input-changes to pg

BEGIN;

    DROP FUNCTION IF EXISTS signer.tx_struct_ore_mine_complete(CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,INTEGER);

    CREATE OR REPLACE FUNCTION signer.tx_struct_ore_mine_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-ore-mine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_struct_ore_refine_complete(CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,INTEGER);

    CREATE OR REPLACE FUNCTION signer.tx_struct_ore_refine_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-ore-refine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_planet_raid_complete(CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,INTEGER);

    CREATE OR REPLACE FUNCTION signer.tx_planet_raid_complete(
        _player_id CHARACTER VARYING,
        _fleet_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','planet-raid-complete',jsonb_build_array(_fleet_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    DROP FUNCTION IF EXISTS signer.tx_struct_build_complete(CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,INTEGER);

    CREATE OR REPLACE FUNCTION signer.tx_struct_build_complete(
        _player_id CHARACTER VARYING,
        _struct_id CHARACTER VARYING,
        _proof CHARACTER VARYING,
        _nonce CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
