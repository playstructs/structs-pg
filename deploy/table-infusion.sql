-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE TABLE structs.infusion (
    destination_type CHARACTER VARYING,
    destination_reactor_id INTEGER,
    destination_struct_id INTEGER,
    address CHARACTER VARYING,

	fuel INTEGER,
	energy INTEGER,

    linked_source_allocation_id INTEGER,
    linked_player_allocation_id INTEGER,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL  
); 

COMMIT;
