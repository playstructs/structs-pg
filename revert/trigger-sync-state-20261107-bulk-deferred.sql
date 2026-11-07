-- Revert structs-pg:trigger-sync-state-20261107-bulk-deferred from pg

BEGIN;

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.fleet FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.fleet FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.fleet FOR EACH ROW WHEN (((old.owner)::text IS DISTINCT FROM (new.owner)::text)) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.grid FOR EACH ROW WHEN ((((old.attribute_type)::text = 'ore'::text) AND (old.val > (0)::numeric))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.grid FOR EACH ROW WHEN ((((new.attribute_type)::text = 'ore'::text) AND (new.val > (0)::numeric))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.grid FOR EACH ROW WHEN ((((new.attribute_type)::text = 'ore'::text) AND (((old.val > (0)::numeric) IS DISTINCT FROM (new.val > (0)::numeric)) OR ((old.object_id)::text IS DISTINCT FROM (new.object_id)::text)))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER grid_notify AFTER INSERT OR UPDATE ON structs.grid FOR EACH ROW EXECUTE FUNCTION structs.grid_notify();

CREATE OR REPLACE TRIGGER inventory_notify AFTER INSERT ON structs.ledger FOR EACH ROW EXECUTE FUNCTION structs.inventory_notify();

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.planet FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.planet FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.planet FOR EACH ROW WHEN (((old.location_list_start)::text IS DISTINCT FROM (new.location_list_start)::text)) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER planet_activity_notify AFTER INSERT ON structs.planet_activity FOR EACH ROW EXECUTE FUNCTION structs.planet_activity_notify();

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.planet_attribute FOR EACH ROW WHEN (((old.attribute_type)::text = ANY ((ARRAY['blockStartOreMine'::character varying, 'blockStartOreRefine'::character varying, 'blockStartRaid'::character varying, 'planetaryShield'::character varying])::text[]))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.planet_attribute FOR EACH ROW WHEN (((new.attribute_type)::text = ANY ((ARRAY['blockStartOreMine'::character varying, 'blockStartOreRefine'::character varying, 'blockStartRaid'::character varying, 'planetaryShield'::character varying])::text[]))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.planet_attribute FOR EACH ROW WHEN (((((new.attribute_type)::text = ANY (ARRAY[('blockStartOreMine'::character varying)::text, ('blockStartOreRefine'::character varying)::text, ('blockStartRaid'::character varying)::text, ('planetaryShield'::character varying)::text])) OR ((old.attribute_type)::text = ANY (ARRAY[('blockStartOreMine'::character varying)::text, ('blockStartOreRefine'::character varying)::text, ('blockStartRaid'::character varying)::text, ('planetaryShield'::character varying)::text]))) AND ((old.val IS DISTINCT FROM new.val) OR ((old.object_id)::text IS DISTINCT FROM (new.object_id)::text) OR ((old.attribute_type)::text IS DISTINCT FROM (new.attribute_type)::text)))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.struct FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.struct FOR EACH ROW EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.struct FOR EACH ROW WHEN (((((((old.owner)::text IS DISTINCT FROM (new.owner)::text) OR (old.type IS DISTINCT FROM new.type)) OR ((old.location_type)::text IS DISTINCT FROM (new.location_type)::text)) OR ((old.location_id)::text IS DISTINCT FROM (new.location_id)::text)) OR (old.is_destroyed IS DISTINCT FROM new.is_destroyed))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_del AFTER DELETE ON structs.struct_attribute FOR EACH ROW WHEN (((old.attribute_type)::text = ANY ((ARRAY['status'::character varying, 'blockStartBuild'::character varying])::text[]))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_ins AFTER INSERT ON structs.struct_attribute FOR EACH ROW WHEN (((new.attribute_type)::text = ANY ((ARRAY['status'::character varying, 'blockStartBuild'::character varying])::text[]))) EXECUTE FUNCTION structs.api_work_mark_dirty();

CREATE OR REPLACE TRIGGER api_work_dirty_upd AFTER UPDATE ON structs.struct_attribute FOR EACH ROW WHEN (((((new.attribute_type)::text = ANY (ARRAY[('status'::character varying)::text, ('blockStartBuild'::character varying)::text])) OR ((old.attribute_type)::text = ANY (ARRAY[('status'::character varying)::text, ('blockStartBuild'::character varying)::text]))) AND ((old.val IS DISTINCT FROM new.val) OR ((old.object_id)::text IS DISTINCT FROM (new.object_id)::text) OR ((old.attribute_type)::text IS DISTINCT FROM (new.attribute_type)::text)))) EXECUTE FUNCTION structs.api_work_mark_dirty();

COMMIT;
