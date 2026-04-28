-- Deploy structs-pg:function-signer-tx-20260427-ugc-overhaul to pg
--
-- structsd v0.16.0 introduces user-generated content (UGC) updates for
-- the four nameable objects: guilds, players, substations, and planets.
-- Two new sets of signer transaction wrappers are added, mirroring the
-- chain's UGCPermissionCheck which accepts EITHER:
--   - PermUpdate (4) on the target object              (self-service)
--   - PermGuildUGCUpdate (16777216) on the actor's guild  (guild moderation)
--
-- Because signer.CREATE_TRANSACTION enforces an exact bitwise permission
-- match against a single object_id, each chain message gets a pair of
-- wrapper functions: tx_<object>_update_<field> for self-service and
-- tx_guild_moderate_<object>_<field> for guild moderation. The exception
-- is the guild itself, where moderating your own guild's name/pfp is
-- functionally the same as the self-service path, so no separate
-- moderation wrapper is provided.
--
-- v0.16.0 also expands the permission bitfield from 24 bits to 25 bits
-- (PermAll: 16777215 -> 33554431) by adding PermGuildUGCUpdate at bit 24.
-- signer.UPDATE_PENDING_ACCOUNT is updated to use the new PermAll constant
-- when stamping the address-register tx for a fresh account.
--
-- Permission constants reference (post-v0.16.0):
--   PermPlay=1, PermAdmin=2, PermUpdate=4, PermDelete=8,
--   PermTokenTransfer=16, PermTokenInfuse=32, PermTokenMigrate=64, PermTokenDefuse=128,
--   PermSourceAllocation=256, PermGuildMembership=512, PermSubstationConnection=1024,
--   PermAllocationConnection=2048, PermGuildTokenBurn=4096, PermGuildTokenMint=8192,
--   PermGuildEndpointUpdate=16384, PermGuildJoinConstraintsUpdate=32768,
--   PermGuildSubstationUpdate=65536, PermProviderWithdraw=131072, PermProviderOpen=262144,
--   PermReactorGuildCreate=524288, PermHashBuild=1048576, PermHashMine=2097152,
--   PermHashRefine=4194304, PermHashRaid=8388608,
--   PermGuildUGCUpdate=16777216, PermAll=33554431

BEGIN;

    -- =========================================================================
    -- Self-service UGC updates (PermUpdate=4 on the target object)
    -- =========================================================================

    -- Guild
    CREATE OR REPLACE FUNCTION signer.tx_guild_update_name(
        _player_id CHARACTER VARYING,
        _guild_id  CHARACTER VARYING,
        _name      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,4,'structs','guild-update-name',jsonb_build_array(_guild_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_update_pfp(
        _player_id CHARACTER VARYING,
        _guild_id  CHARACTER VARYING,
        _pfp       CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,4,'structs','guild-update-pfp',jsonb_build_array(_guild_id, _pfp),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Player
    CREATE OR REPLACE FUNCTION signer.tx_player_update_name(
        _player_id CHARACTER VARYING,
        _name      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-name',jsonb_build_array(_player_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp(
        _player_id CHARACTER VARYING,
        _pfp       CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-pfp',jsonb_build_array(_player_id, _pfp),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Substation
    CREATE OR REPLACE FUNCTION signer.tx_substation_update_name(
        _player_id     CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _name          CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-update-name',jsonb_build_array(_substation_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_substation_update_pfp(
        _player_id     CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _pfp           CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-update-pfp',jsonb_build_array(_substation_id, _pfp),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Planet
    CREATE OR REPLACE FUNCTION signer.tx_planet_update_name(
        _player_id CHARACTER VARYING,
        _planet_id CHARACTER VARYING,
        _name      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_planet_id,4,'structs','planet-update-name',jsonb_build_array(_planet_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    -- =========================================================================
    -- Guild moderation UGC updates (PermGuildUGCUpdate=16777216 on the guild)
    -- =========================================================================

    -- Player rename / re-pfp by a guild moderator
    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_name(
        _player_id        CHARACTER VARYING,
        _guild_id         CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _name             CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-name',jsonb_build_array(_target_player_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp(
        _player_id        CHARACTER VARYING,
        _guild_id         CHARACTER VARYING,
        _target_player_id CHARACTER VARYING,
        _pfp              CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-pfp',jsonb_build_array(_target_player_id, _pfp),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Substation rename / re-pfp by a guild moderator
    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_name(
        _player_id     CHARACTER VARYING,
        _guild_id      CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _name          CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','substation-update-name',jsonb_build_array(_substation_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_pfp(
        _player_id     CHARACTER VARYING,
        _guild_id      CHARACTER VARYING,
        _substation_id CHARACTER VARYING,
        _pfp           CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','substation-update-pfp',jsonb_build_array(_substation_id, _pfp),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Planet rename by a guild moderator
    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_planet_name(
        _player_id CHARACTER VARYING,
        _guild_id  CHARACTER VARYING,
        _planet_id CHARACTER VARYING,
        _name      CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','planet-update-name',jsonb_build_array(_planet_id, _name),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;


    -- =========================================================================
    -- Update UPDATE_PENDING_ACCOUNT: PermAll 16777215 -> 33554431
    -- =========================================================================

    CREATE OR REPLACE FUNCTION signer.UPDATE_PENDING_ACCOUNT(_account_id INTEGER, _player_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING, _permission INTEGER) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;

        INSERT INTO signer.tx (object_id, module, command, args, permission_requirement )
            VALUES (_player_id, 'structs', 'address-register', jsonb_build_array(_address , _pubkey ,_signature , _permission), 33554431);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;

COMMIT;
