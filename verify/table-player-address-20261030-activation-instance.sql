-- Verify structs-pg:table-player-address-20261030-activation-instance on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT activation_id,code,player_id FROM structs.player_address_activation_code LIMIT 0;
SELECT activation_id,code,address FROM structs.player_address_pending LIMIT 0;
SELECT 1/(has_column_privilege(current_user,'structs.player_address_pending','activation_id','INSERT')
    AND has_column_privilege(current_user,'structs.player_address_pending','activation_id','UPDATE'))::int;
RESET ROLE;
SELECT 1/(count(*)=3)::int FROM pg_constraint WHERE conname IN
    ('player_address_activation_instance','player_address_pending_activation_instance','player_address_pending_one_device');
ROLLBACK;
