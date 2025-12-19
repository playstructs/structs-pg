-- Deploy structs-pg:view-permission-20251218-add-permission-hash to pg

BEGIN;

/*
 These should reflect the values found in the permission.go type in structsd
 https://github.com/playstructs/structsd/blob/master/x/structs/types/permissions.go

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

    DROP VIEW IF EXISTS view.permission_address;

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
        (permission.val & 128) > 0 as permission_hash,
        permission.updated_at

    FROM structs.permission
    WHERE permission.object_type = 'address';

    DROP VIEW IF EXISTS view.permission_player;

    CREATE OR REPLACE VIEW view.permission_player AS
    SELECT
        permission.object_id as object_id,
        permission.object_type as object_type,
        permission.player_id as player_id,

        (permission.val & 1) > 0 as permission_play,
        (permission.val & 2) > 0 as permission_update,
        (permission.val & 4) > 0 as permission_delete,
        (permission.val & 8) > 0 as permission_assets,
        (permission.val & 16) > 0 as permission_associations,
        (permission.val & 32) > 0 as permission_grid,
        (permission.val & 64) > 0 as permissions,
        (permission.val & 128) > 0 as permission_hash,
        permission.updated_at

    FROM structs.permission
    WHERE permission.object_type != 'address';

COMMIT;
