-- Revert structs-pg:table-stat-20260522-add-block-height from pg

BEGIN;

    ALTER TABLE structs.stat_ore                  DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_fuel                 DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_capacity             DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_load                 DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_structs_load         DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_power                DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_connection_capacity  DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_connection_count     DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_struct_health        DROP COLUMN IF EXISTS block_height;
    ALTER TABLE structs.stat_struct_status        DROP COLUMN IF EXISTS block_height;

COMMIT;
