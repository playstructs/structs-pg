-- Deploy structs-pg:table-struct-20260207-add-destroyed-block to pg

BEGIN;

    ALTER TABLE structs.struct ADD COLUMN destroyed_block BIGINT;

    INSERT INTO structs.setting VALUES ('STRUCT_SWEEP_DELAY','5', NOW());

COMMIT;
