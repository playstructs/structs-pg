-- Deploy structs-pg:table-allocation to pg

BEGIN;

CREATE TABLE structs.allocation (
	id INTEGER PRIMARY KEY, 
	power NUMERIC, 
	source_type CHARACTER VARYING,
	source_reactor_id INTEGER,
	source_struct_id INTEGER,
	source_substation_id INTEGER,
	destination_id INTEGER, 
	controller CHARACTER VARYING,
	status CHARACTER VARYING, 
	created_at TIMESTAMPTZ NOT NULL, 
	updated_at	TIMESTAMPTZ NOT NULL  
); 

COMMIT;
