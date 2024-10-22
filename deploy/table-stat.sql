-- Deploy structs-pg:table-stat to pg

BEGIN;

CREATE TYPE structs.stat_description AS ENUM (
    'ore',
    'fuel',
    'capacity',
    'load',
    'structs load',
    'power',
    'connection capacity',
    'connection count',
    'health',
    'status'
);

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
    'fleet'
);

CREATE TABLE structs.stat (
    time	        TIMESTAMPTZ NOT NULL,
    description     structs.stat_description NOT NULL,
    object_type     structs.object_type NOT NULL,
    object_index    INTEGER NOT NULL,
    value           INTEGER
);


SELECT create_hypertable('structs.stat', by_range('time'));

COMMIT;
