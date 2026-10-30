-- Deploy structs-pg:function-signer-authority-20261030 to pg
BEGIN;

-- Read models for account selection, not a substitute for chain authorization.
-- Match v0.22.0 (96cea3a3) permissions_context.go. Resolve the current object
-- directly: player_object is a historical sidecar and cannot confer authority.
CREATE FUNCTION signer.PERMISSION_OBJECT_OWNER(_object_id CHARACTER VARYING)
RETURNS CHARACTER VARYING AS
$BODY$
DECLARE
    _owner CHARACTER VARYING;
BEGIN
    CASE split_part(_object_id, '-', 1)
        WHEN '0' THEN SELECT owner INTO _owner FROM structs.guild WHERE id=_object_id;
        WHEN '1' THEN SELECT id INTO _owner FROM structs.player WHERE id=_object_id;
        WHEN '2' THEN SELECT owner INTO _owner FROM structs.planet WHERE id=_object_id;
        WHEN '3' THEN SELECT owner INTO _owner FROM structs.reactor WHERE id=_object_id;
        WHEN '4' THEN SELECT owner INTO _owner FROM structs.substation WHERE id=_object_id;
        WHEN '5' THEN SELECT owner INTO _owner FROM structs.struct WHERE id=_object_id AND NOT is_destroyed;
        WHEN '6' THEN SELECT controller INTO _owner FROM structs.allocation WHERE id=_object_id;
        WHEN '9' THEN SELECT owner INTO _owner FROM structs.fleet WHERE id=_object_id;
        WHEN '10' THEN SELECT owner INTO _owner FROM structs.provider WHERE id=_object_id;
        WHEN '11' THEN SELECT owner INTO _owner FROM structs.agreement WHERE id=_object_id;
        ELSE RETURN NULL;
    END CASE;
    RETURN NULLIF(_owner, '');
END
$BODY$
LANGUAGE plpgsql STABLE;

CREATE FUNCTION signer.PERMISSION_CHECK(
    _address CHARACTER VARYING,
    _object_id CHARACTER VARYING,
    _permission INTEGER
) RETURNS BOOLEAN AS
$BODY$
DECLARE
    _player_id CHARACTER VARYING;
    _guild_id CHARACTER VARYING;
    _guild_rank NUMERIC;
    _key_permission INTEGER;
    _owner CHARACTER VARYING;
BEGIN
    IF _permission IS NULL OR _permission < 1 OR _permission > 33554431 THEN
        RETURN FALSE;
    END IF;

    -- Association is resolved live; permission.player_id is insert-time metadata.
    -- A vault is an economic account and must never become a signing identity.
    SELECT p.id,p.guild_id,p.guild_rank,permission.val
      INTO _player_id,_guild_id,_guild_rank,_key_permission
      FROM structs.player_address pa
      JOIN structs.player p ON p.id=pa.player_id
      JOIN structs.permission permission ON permission.id='8-' || pa.address || '@0'
     WHERE pa.address=_address AND pa.status='approved'
       AND NOT EXISTS (SELECT 1 FROM structs.vault v WHERE v.address=pa.address);
    IF _player_id IS NULL OR _key_permission IS NULL
        OR (_key_permission & _permission) <> _permission THEN
        RETURN FALSE;
    END IF;

    _owner := signer.PERMISSION_OBJECT_OWNER(_object_id);
    IF _owner IS NULL THEN RETURN FALSE; END IF;
    IF _owner = _player_id THEN RETURN TRUE; END IF;
    IF EXISTS (SELECT 1 FROM structs.guild WHERE id=_owner AND owner=_player_id) THEN
        RETURN TRUE;
    END IF;
    IF EXISTS (SELECT 1 FROM structs.permission
        WHERE id=_object_id || '@' || _player_id AND (val & _permission)=_permission) THEN
        RETURN TRUE;
    END IF;

    -- Rank never grants administration. All bits must be present in the same
    -- rank register; don't combine incomplete direct grants with rank grants.
    IF (_permission & 2) <> 0 OR _guild_rank IS NULL
        OR NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_guild_id) THEN
        RETURN FALSE;
    END IF;
    RETURN NOT EXISTS (
        SELECT 1 FROM generate_series(0,24) AS bits(bit)
        LEFT JOIN structs.permission_guild_rank r
          ON r.object_id=_object_id AND r.guild_id=_guild_id AND r.permission=(1::bigint << bits.bit)
        WHERE (_permission & (1 << bits.bit)) <> 0
          AND (r.rank IS NULL OR r.rank=0 OR r.rank < _guild_rank)
    );
END
$BODY$
LANGUAGE plpgsql STABLE;

CREATE FUNCTION signer.CAN_OPEN_AGREEMENT(
    _address CHARACTER VARYING,
    _provider_id CHARACTER VARYING,
    _owner_id CHARACTER VARYING
) RETURNS BOOLEAN AS
$BODY$
DECLARE
    _policy CHARACTER VARYING;
BEGIN
    -- Provider access and authority over the collateral owner are separate.
    IF _owner_id IS NULL OR split_part(_owner_id,'-',1) NOT IN ('0','1')
        OR NOT signer.PERMISSION_CHECK(_address,_owner_id,16) THEN
        RETURN FALSE;
    END IF;
    SELECT access_policy INTO _policy FROM structs.provider WHERE id=_provider_id;
    CASE _policy
        WHEN 'openMarket' THEN RETURN TRUE;
        WHEN 'guildMarket' THEN RETURN signer.PERMISSION_CHECK(_address,_provider_id,262144);
        ELSE RETURN FALSE;
    END CASE;
END
$BODY$
LANGUAGE plpgsql STABLE;

COMMIT;
