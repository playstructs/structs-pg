-- Deploy structs-pg:view-player to pg

BEGIN;

CREATE OR REPLACE VIEW view.player AS
        SELECT
            id as player_id,
            guild_id,
            substation_id,
            planet_id,
            fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || player.id),0) as ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id),0) as load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id),0) as structs_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id),0) as capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || player.substation_id),0) as connection_capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id),0) as total_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || player.substation_id),0)  as total_capacity,
            primary_address,
            created_at,
            updated_at
        FROM structs.player;


/*
 const (
    // 1
	PermissionPlay Permission = 1 << iota
	// 2
	PermissionUpdate
	// 4
	PermissionDelete
	// 8
	PermissionAssets
	// 16
	PermissionAssociations
	// 32
	PermissionGrid
	// 64
	Permissions
)
 */

CREATE OR REPLACE VIEW view.permission_address AS
    SELECT
        permission.object_index as address,
        (permission.val & 1) > 0 as permission_play,
        (permission.val & 2) > 0 as permission_update,
        (permission.val & 4) > 0 as permission_delete,
        (permission.val & 8) > 0 as permission_assets,
        (permission.val & 16) > 0 as permission_associations,
        (permission.val & 32) > 0 as permission_grid,
        (permission.val & 64) > 0 as permissions,
        permission.updated_at

    FROM structs.permission
    WHERE permission.object_type = 0;

CREATE OR REPLACE VIEW view.permission_player AS
SELECT
        permission.object_id as object_id,
        permission.player_id as player_id,

        (permission.val & 1) > 0 as permission_play,
        (permission.val & 2) > 0 as permission_update,
        (permission.val & 4) > 0 as permission_delete,
        (permission.val & 8) > 0 as permission_assets,
        (permission.val & 16) > 0 as permission_associations,
        (permission.val & 32) > 0 as permission_grid,
        (permission.val & 64) > 0 as permissions,
        permission.updated_at

FROM structs.permission
WHERE permission.object_type != 0;


COMMIT;

