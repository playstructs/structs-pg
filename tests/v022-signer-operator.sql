\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
SET LOCAL ROLE structs_tsa;
DO $$
DECLARE request JSONB; repeated JSONB; key_request JSONB;
    retry_id UUID := '40000000-0000-0000-0000-000000000001';
BEGIN
    request := signer.REQUEST_ROLE_V022('manual role fixture','0-990940',33554431,retry_id);
    repeated := signer.REQUEST_ROLE_V022('manual role fixture','0-990940',33554431,retry_id);
    IF request IS NULL OR request IS DISTINCT FROM repeated THEN RAISE EXCEPTION 'operator retry duplicated role identity'; END IF;
    BEGIN
        PERFORM signer.REQUEST_ROLE_V022('another role','0-990940',33554431,retry_id);
        RAISE EXCEPTION 'operator UUID was repurposed';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
    BEGIN
        PERFORM signer.REQUEST_ROLE_V022('invalid grant','0-990940',127,gen_random_uuid());
        RAISE EXCEPTION 'operator role silently broadened an incomplete primary grant';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    IF has_table_privilege(current_user,'signer.role','INSERT')
        OR has_table_privilege(current_user,'signer.account','UPDATE')
        OR has_table_privilege(current_user,'structs.permission','UPDATE') THEN
        RAISE EXCEPTION 'worker can bypass guarded mutations'; END IF;
    BEGIN
        PERFORM signer.REQUEST_ACCOUNT_V022(990940,16,41,gen_random_uuid(),'manual');
        RAISE EXCEPTION 'manual request exceeded role limit';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    key_request := signer.REQUEST_ACCOUNT_V022(990940,16,40,'40000000-0000-0000-0000-000000000002','manual');
    IF key_request->>'permissions'<>'16' THEN RAISE EXCEPTION 'explicit manual key grant changed'; END IF;
END $$;
RESET ROLE;
DO $$
BEGIN
    BEGIN
        UPDATE signer.role_key_request SET username='changed identity';
        RAISE EXCEPTION 'role key identity was mutable';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
ROLLBACK;
