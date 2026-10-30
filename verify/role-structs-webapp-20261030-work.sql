-- Verify structs-pg:role-structs-webapp-20261030-work on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT object_id,player_id,target_id,category,block_start,difficulty_target,
    location_type,location_id,planet_id FROM view.work LIMIT 0;
DO $$
BEGIN
    IF has_table_privilege(current_user,'view.work','INSERT,UPDATE,DELETE')
        OR has_table_privilege(current_user,'structs.api_work','INSERT,UPDATE,DELETE,TRUNCATE') THEN
        RAISE EXCEPTION 'webapp work access must remain read-only';
    END IF;
END;
$$;
ROLLBACK;
