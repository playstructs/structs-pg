-- Deploy structs-pg:function-signer-tx-20260825-v021-messages to pg
--
-- structsd v0.21.0 signer wrappers.
--
-- New:
--   tx_guild_bank_convert / tx_guild_bank_convert_token
--   tx_guild_update_bank_convert_in_fee / tx_guild_update_bank_convert_out_fee
--   tx_reactor_restart
--   tx_guild_create_charter  (same command guild-create, extra flags)
--
-- Updated (DROP + recreate; CREATE OR REPLACE cannot change arg lists):
--   tx_guild_bank_redeem           + required minAmountAlpha
--   tx_guild_bank_mint             + required --guild-id flag
--   tx_guild_bank_confiscate_and_burn  + --guild-id; arg order amount then address
--   tx_guild_update_entry_rank     + player_id + --guild-id
--   tx_player_update_guild_rank    + --guild-id
--
-- Perm bits: PermPlay=1, PermAdmin=2, PermTokenTransfer=16,
-- PermGuildTokenBurn=4096, PermGuildTokenMint=8192,
-- PermGuildJoinInfusionMinimumUpdate=32768, PermGuildMembership=512,
-- PermReactorGuildCreate=524288.

BEGIN;

    -- -------------------------------------------------------------------------
    -- New messages
    -- -------------------------------------------------------------------------

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert(
        _player_id        CHARACTER VARYING,
        _guild_id         CHARACTER VARYING,
        _amount_alpha     NUMERIC,
        _min_amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-convert',
            jsonb_build_array(_guild_id, _amount_alpha, _min_amount_token),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert_token(
        _player_id        CHARACTER VARYING,
        _amount_token     NUMERIC,
        _denom            CHARACTER VARYING,
        _target_guild_id  CHARACTER VARYING,
        _min_amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    DECLARE
        _real_denom  CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom  := _denom;
            _real_amount := _amount_token;
        ELSE
            _real_denom  := 'u' || _denom;
            _real_amount := _amount_token * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-convert-token',
            jsonb_build_array(_real_amount || _real_denom, _target_guild_id, _min_amount_token),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_in_fee(
        _player_id CHARACTER VARYING,
        _guild_id  CHARACTER VARYING,
        _fee       CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            2,
            'structs',
            'guild-update-bank-convert-in-fee',
            jsonb_build_array(_guild_id, _fee),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_out_fee(
        _player_id CHARACTER VARYING,
        _guild_id  CHARACTER VARYING,
        _fee       CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            2,
            'structs',
            'guild-update-bank-convert-out-fee',
            jsonb_build_array(_guild_id, _fee),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_reactor_restart(
        _player_id          CHARACTER VARYING,
        _validator_address  CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            1,
            'structs',
            'reactor-restart',
            jsonb_build_array(_validator_address),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Same command as tx_guild_create (MsgGuildCreate); extra flags are the
    -- charter proof / third-party founder fields. Not guild-create-compute.
    CREATE OR REPLACE FUNCTION signer.tx_guild_create_charter(
        _player_id            CHARACTER VARYING,
        _reactor_id           CHARACTER VARYING,
        _endpoint             CHARACTER VARYING,
        _entry_substation_id  CHARACTER VARYING,
        _proof                CHARACTER VARYING,
        _nonce                CHARACTER VARYING,
        _founder_player_id    CHARACTER VARYING DEFAULT NULL,
        _address              CHARACTER VARYING DEFAULT NULL,
        _proof_pub_key        CHARACTER VARYING DEFAULT NULL,
        _proof_signature      CHARACTER VARYING DEFAULT NULL
    ) RETURNS void AS
    $BODY$
    DECLARE
        _flags JSONB;
    BEGIN
        _flags := jsonb_build_object('proof', _proof, 'nonce', _nonce);
        IF _founder_player_id IS NOT NULL AND _founder_player_id <> '' THEN
            _flags := _flags || jsonb_build_object('founder-player-id', _founder_player_id);
        END IF;
        IF _address IS NOT NULL AND _address <> '' THEN
            _flags := _flags || jsonb_build_object('address', _address);
        END IF;
        IF _proof_pub_key IS NOT NULL AND _proof_pub_key <> '' THEN
            _flags := _flags || jsonb_build_object('proof-pub-key', _proof_pub_key);
        END IF;
        IF _proof_signature IS NOT NULL AND _proof_signature <> '' THEN
            _flags := _flags || jsonb_build_object('proof-signature', _proof_signature);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            _reactor_id,
            524288,
            'structs',
            'guild-create',
            jsonb_build_array(_reactor_id, _endpoint, _entry_substation_id),
            _flags
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- -------------------------------------------------------------------------
    -- Updated existing wrappers
    -- -------------------------------------------------------------------------

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_redeem(CHARACTER VARYING, NUMERIC, CHARACTER VARYING);
    CREATE FUNCTION signer.tx_guild_bank_redeem(
        _player_id        CHARACTER VARYING,
        _amount           NUMERIC,
        _denom            CHARACTER VARYING,
        _min_amount_alpha NUMERIC
    ) RETURNS void AS
    $BODY$
    DECLARE
        _real_denom  CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom  := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom  := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-redeem',
            jsonb_build_array(_real_amount || _real_denom, _min_amount_alpha),
            '{}'
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_mint(CHARACTER VARYING, NUMERIC, NUMERIC);
    CREATE FUNCTION signer.tx_guild_bank_mint(
        _player_id     CHARACTER VARYING,
        _amount_alpha  NUMERIC,
        _amount_token  NUMERIC,
        _guild_id      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            8192,
            'structs',
            'guild-bank-mint',
            jsonb_build_array(_amount_alpha, _amount_token),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_confiscate_and_burn(CHARACTER VARYING, CHARACTER VARYING, NUMERIC);
    CREATE FUNCTION signer.tx_guild_bank_confiscate_and_burn(
        _player_id     CHARACTER VARYING,
        _amount_token  NUMERIC,
        _address       CHARACTER VARYING,
        _guild_id      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            4096,
            'structs',
            'guild-bank-confiscate-and-burn',
            jsonb_build_array(_amount_token, _address),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_update_entry_rank(CHARACTER VARYING, BIGINT);
    CREATE FUNCTION signer.tx_guild_update_entry_rank(
        _player_id      CHARACTER VARYING,
        _guild_id       CHARACTER VARYING,
        _new_entry_rank BIGINT
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            32768,
            'structs',
            'guild-update-entry-rank',
            jsonb_build_array(_new_entry_rank),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_player_update_guild_rank(CHARACTER VARYING, BIGINT);
    CREATE FUNCTION signer.tx_player_update_guild_rank(
        _target_player_id CHARACTER VARYING,
        _guild_rank       BIGINT,
        _guild_id         CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _target_player_id,
            512,
            'structs',
            'player-update-guild-rank',
            jsonb_build_array(_target_player_id, _guild_rank),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
