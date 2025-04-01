-- Deploy structs-pg:table-allocation to pg

BEGIN;

CREATE TABLE structs.allocation (
	id CHARACTER VARYING PRIMARY KEY,

    allocation_type CHARACTER VARYING,

	source_id CHARACTER VARYING,
    index INTEGER,
	destination_id CHARACTER VARYING,

    creator CHARACTER VARYING,
    controller CHARACTER VARYING,
    locked boolean,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW()
); 

COMMIT;


select id,
       allocation_type,
       source_id,
       destination_id,
       controller,
       structs.UNIT_DISPLAY_FORMAT(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='5-' || allocation.id),0),'milliwatt') as capacity,
from structs.allocation;