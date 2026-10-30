-- Deploy structs-pg:function-signer-operator-20261030 to pg
BEGIN;
CREATE TABLE signer.role_operator_request (
    request_id UUID PRIMARY KEY,
    role_id INTEGER NOT NULL UNIQUE REFERENCES signer.role(id) ON DELETE RESTRICT,
    username VARCHAR NOT NULL,
    guild_id VARCHAR NOT NULL,
    permissions INTEGER NOT NULL CHECK (permissions=33554431),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER role_operator_request_immutable BEFORE UPDATE OR DELETE ON signer.role_operator_request
    FOR EACH ROW EXECUTE FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022();
CREATE FUNCTION signer.REQUEST_ROLE_V022(_name VARCHAR,_guild_id VARCHAR,_permissions INTEGER,_request_id UUID)
RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _saved signer.role_operator_request%ROWTYPE; _role_id INTEGER; _context RECORD;
BEGIN
    IF _name IS NULL OR length(_name) NOT BETWEEN 1 AND 128 OR _guild_id IS NULL
        OR _guild_id !~ '^0-[1-9][0-9]*$' OR _permissions IS DISTINCT FROM 33554431 OR _request_id IS NULL THEN
        RAISE EXCEPTION 'manual role request requires a name, guild, request UUID and full primary grant' USING ERRCODE='22023'; END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended('tsa-role-request:' || _request_id::text,0));
    SELECT * INTO _saved FROM signer.role_operator_request WHERE request_id=_request_id;
    IF FOUND THEN
        IF (_saved.username,_saved.guild_id,_saved.permissions) IS DISTINCT FROM (_name,_guild_id,_permissions) THEN
            RAISE EXCEPTION 'role request UUID identifies a different request' USING ERRCODE='55000'; END IF;
        RETURN signer.ROLE_KEY_REQUEST_V022(_saved.role_id);
    END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0'
        OR NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_guild_id) THEN
        RAISE EXCEPTION 'guild index is not ready for a new role' USING ERRCODE='55000'; END IF;
    INSERT INTO structs.player_internal_pending(username,guild_id) VALUES(_name,_guild_id) RETURNING role_id INTO _role_id;
    INSERT INTO signer.role_operator_request(request_id,role_id,username,guild_id,permissions)
    VALUES(_request_id,_role_id,_name,_guild_id,_permissions);
    RETURN signer.PREPARE_ROLE_KEY_V022(_role_id,_permissions);
END
$BODY$;
REVOKE ALL ON TABLE signer.role_operator_request FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.REQUEST_ROLE_V022(VARCHAR,VARCHAR,INTEGER,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION signer.REQUEST_ROLE_V022(VARCHAR,VARCHAR,INTEGER,UUID) TO structs_tsa;
COMMIT;
