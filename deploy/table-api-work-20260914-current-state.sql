-- Deploy structs-pg:table-api-work-20260914-current-state to pg
--
-- Current-state projection of view.work, maintained by sync-state like the
-- other structs.api_* read models. view.work rebuilds the BUILD / MINE /
-- REFINE / RAID work list from structs.struct, struct_attribute, struct_type,
-- grid, planet, planet_attribute and fleet on every read; a single
-- SELECT count(*) FROM view.work costs ~180 ms and ~145k buffer hits and the
-- webapp calls it several times a minute.
--
-- Columns and types match view.work exactly so view.work can later be
-- re-pointed at this table (as view-inventory-20260914-read-api-current-state
-- did for the inventory views) without touching webapp SQL. The table is
-- empty until sync-state backfills it; view.work keeps its live definition
-- until then.
--
-- Natural key: a struct appears at most once per category, and a RAID row is
-- (fleet at location_list_start, planet), so (category, object_id, target_id)
-- is unique.

BEGIN;

    CREATE TABLE structs.api_work (
        object_id         CHARACTER VARYING NOT NULL,
        player_id         CHARACTER VARYING,
        target_id         CHARACTER VARYING NOT NULL,
        category          TEXT NOT NULL
                          CHECK (category IN ('BUILD', 'MINE', 'REFINE', 'RAID')),
        block_start       INTEGER,
        difficulty_target INTEGER,
        location_type     CHARACTER VARYING,
        location_id       CHARACTER VARYING,
        planet_id         CHARACTER VARYING,
        source_height     BIGINT,
        updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (category, object_id, target_id)
    );

    COMMENT ON TABLE structs.api_work IS
        'Current work list (BUILD/MINE/REFINE/RAID), one row per available work item. Same columns as view.work plus source_height/updated_at. Maintained by sync-state; empty until backfilled.';
    COMMENT ON COLUMN structs.api_work.block_start IS
        'Block height the current clock started at (0 when no clock attribute exists), as in view.work.';
    COMMENT ON COLUMN structs.api_work.difficulty_target IS
        'Difficulty target for the category from struct_type, or the planet shield value for RAID, as in view.work.';
    COMMENT ON COLUMN structs.api_work.source_height IS
        'Block height whose state this row reflects.';

    CREATE INDEX api_work_player_idx
        ON structs.api_work (player_id, category, object_id, target_id);
    CREATE INDEX api_work_planet_idx
        ON structs.api_work (planet_id, category, object_id, target_id);
    CREATE INDEX api_work_category_idx
        ON structs.api_work (category, planet_id, object_id, target_id);

COMMIT;
