-- Deploy structs-pg:view-guild to pg

BEGIN;

CREATE OR REPLACE VIEW view.guild AS
    SELECT
       *

        -- primary reactor fuel infused
        -- primary reactor power generating capacity
        -- primary reactor power allocated in
        -- primary reactor power allocation out
        -- primary reactor power commission capacity

        -- primary substation
        -- primary substation capacity
        -- primary substation allocation_out_load
        -- primary substation player connection count
        -- primary substation player connection capacity
        -- primary substation player struct load avg


    FROM structs.guild;


COMMIT;
