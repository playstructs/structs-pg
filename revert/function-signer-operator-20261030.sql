-- Revert structs-pg:function-signer-operator-20261030 from pg
BEGIN;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM signer.role_operator_request) THEN
    RAISE EXCEPTION 'preserve manual role request history before reverting'; END IF; END $$;
DROP FUNCTION signer.REQUEST_ROLE_V022(VARCHAR,VARCHAR,INTEGER,UUID);
DROP TABLE signer.role_operator_request;
COMMIT;
