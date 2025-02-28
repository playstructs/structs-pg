-- Deploy structs-pg:table-stat to pg

BEGIN;

    CREATE TYPE structs.object_type AS ENUM (
        'guild',
        'player',
        'planet',
        'reactor',
        'substation',
        'struct',
        'allocation',
        'infusion',
        'address',
        'fleet',
        'provider',
        'agreement'
    );

    CREATE OR REPLACE FUNCTION structs.GET_OBJECT_ID(object_type structs.object_type, index INTEGER) RETURNS CHARACTER VARYING AS
    $BODY$
    BEGIN
      RETURN (CASE object_type
                  WHEN 'guild' THEN '0'
                  WHEN 'player' THEN '1'
                  WHEN 'planet' THEN '2'
                  WHEN 'reactor' THEN '3'
                  WHEN 'substation' THEN '4'
                  WHEN 'struct' THEN '5'
                  WHEN 'allocation' THEN '6'
                  WHEN 'infusion' THEN '7'
                  WHEN 'address' THEN '8'
                  WHEN 'fleet' THEN '9'
                  WHEN 'provider' THEN '10'
                  WHEN 'agreement' THEN '11'
          END) || '-' || index;
    END;
    $BODY$
    LANGUAGE plpgsql IMMUTABLE COST 100;

    CREATE OR REPLACE FUNCTION structs.GET_OBJECT_TYPE(object_id INTEGER) RETURNS structs.object_type AS
    $BODY$
        BEGIN
           RETURN (CASE object_id
                WHEN 0 THEN 'guild'
                WHEN 1 THEN 'player'
                WHEN 2 THEN 'planet'
                WHEN 3 THEN 'reactor'
                WHEN 4 THEN 'substation'
                WHEN 5 THEN 'struct'
                WHEN 6 THEN 'allocation'
                WHEN 7 THEN 'infusion'
                WHEN 8 THEN 'address'
                WHEN 9 THEN 'fleet'
                WHEN 10 THEN 'provider'
                WHEN 11 THEN 'agreement'
                ELSE null
                END)::structs.object_type;
        END
    $BODY$
    LANGUAGE plpgsql IMMUTABLE COST 100;

    CREATE TABLE structs.stat_ore (
        time	        TIMESTAMPTZ NOT NULL,
        object_type     structs.object_type NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_ore', by_range('time'));

    CREATE TABLE structs.stat_fuel (
       time	        TIMESTAMPTZ NOT NULL,
       object_type     structs.object_type NOT NULL,
       object_index    INTEGER NOT NULL,
       value           INTEGER
    );

    SELECT create_hypertable('structs.stat_fuel', by_range('time'));

    CREATE TABLE structs.stat_capacity (
       time	        TIMESTAMPTZ NOT NULL,
       object_type     structs.object_type NOT NULL,
       object_index    INTEGER NOT NULL,
       value           INTEGER
    );

    SELECT create_hypertable('structs.stat_capacity', by_range('time'));

    CREATE TABLE structs.stat_load (
       time	        TIMESTAMPTZ NOT NULL,
       object_type     structs.object_type NOT NULL,
       object_index    INTEGER NOT NULL,
       value           INTEGER
    );

    SELECT create_hypertable('structs.stat_load', by_range('time'));

    CREATE TABLE structs.stat_structs_load (
        time	        TIMESTAMPTZ NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_structs_load', by_range('time'));

    CREATE TABLE structs.stat_power (
        time	        TIMESTAMPTZ NOT NULL,
        object_type     structs.object_type NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_power', by_range('time'));

    CREATE TABLE structs.stat_connection_count (
        time	        TIMESTAMPTZ NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_connection_count', by_range('time'));

    CREATE TABLE structs.stat_connection_capacity (
       time	        TIMESTAMPTZ NOT NULL,
       object_index    INTEGER NOT NULL,
       value           INTEGER
    );

    SELECT create_hypertable('structs.stat_connection_capacity', by_range('time'));

    CREATE TABLE structs.stat_struct_health (
        time	        TIMESTAMPTZ NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_struct_health', by_range('time'));

    CREATE TABLE structs.stat_struct_status (
        time	        TIMESTAMPTZ NOT NULL,
        object_index    INTEGER NOT NULL,
        value           INTEGER
    );

    SELECT create_hypertable('structs.stat_struct_status', by_range('time'));



COMMIT;

