-- Verify structs-pg:role-structs-webapp-20261030-device-metadata on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT address,player_id,block_time FROM structs.player_address_activity LIMIT 0;
SELECT address,ip,user_agent,updated_at FROM structs.player_address_meta LIMIT 0;
SELECT address,denom,balance FROM view.address_inventory LIMIT 0;
DO $$
BEGIN
    -- Check this migration's explicit grants even on legacy superuser service
    -- roles. Effective privilege restrictions also apply to restricted roles.
    IF EXISTS (SELECT 1 FROM (VALUES
            ('structs.player_address_activity'::regclass,'SELECT'),
            ('view.address_inventory'::regclass,'SELECT'),
            ('structs.player_address_meta'::regclass,'SELECT'),
            ('structs.player_address_meta'::regclass,'INSERT'),
            ('structs.player_address_meta'::regclass,'UPDATE')) required(relation,privilege)
        WHERE NOT EXISTS (SELECT 1 FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE c.oid=required.relation AND a.grantee=current_user::regrole::oid
                AND a.privilege_type=required.privilege))
        OR EXISTS (SELECT 1 FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE a.grantee IN (0,current_user::regrole::oid) AND (
                (c.oid='structs.player_address_meta'::regclass AND a.privilege_type IN ('DELETE','TRUNCATE'))
                OR (c.oid IN ('structs.player_address_activity'::regclass,'view.address_inventory'::regclass)
                    AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))))
        OR (NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) AND (
            has_table_privilege(current_user,'structs.player_address_meta','DELETE,TRUNCATE')
            OR has_table_privilege(current_user,'structs.player_address_activity','INSERT,UPDATE,DELETE,TRUNCATE')
            OR has_table_privilege(current_user,'view.address_inventory','INSERT,UPDATE,DELETE'))) THEN
        RAISE EXCEPTION 'incorrect webapp device metadata privileges';
    END IF;
END;
$$;
ROLLBACK;
