-- Verify structs-pg:table-player-address-pending-20261030-proof-context on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT code,address,player_id,guild_id,proof_chain_id,proof_protocol,
    proof_nonce::text,proof_height::text,proof_timeout_height::text
FROM structs.player_address_pending LIMIT 0;
SELECT code,player_id,logged_in_address,created_at FROM structs.player_address_activation_code LIMIT 0 FOR UPDATE;
SELECT 1 / (has_table_privilege(current_user,'structs.player_address_pending','INSERT')
    AND has_table_privilege(current_user,'structs.player_address_pending','UPDATE')
    AND has_table_privilege(current_user,'structs.player_address_activation_code','INSERT')
    AND has_table_privilege(current_user,'structs.player_address_activation_code','DELETE'))::int;
ROLLBACK;
