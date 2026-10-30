-- Verify structs-pg:function-signer-authority-20261030 on pg
BEGIN;
SELECT 1 / (signer.PERMISSION_OBJECT_OWNER('unknown') IS NULL
    AND NOT signer.PERMISSION_CHECK(NULL,NULL,0)
    AND NOT signer.CAN_OPEN_AGREEMENT(NULL,NULL,NULL))::int;
ROLLBACK;
