-- Revert structs-pg:function-signer-tx-20261030-cosmetic from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN ('guild-update-name','guild-update-pfp','guild-update-entry-substation-id','player-update-name','player-update-pfp','player-update-pfp-cr-attributes','planet-update-name'))
        OR EXISTS (SELECT 1 FROM signer.tx_authority WHERE check_type IN ('ugc','station-connection')) THEN
        RAISE EXCEPTION 'versioned cosmetic requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_planet_name(_player_id character varying, _guild_id character varying, _planet_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','planet-update-name',jsonb_build_array(_planet_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_name(_player_id character varying, _guild_id character varying, _target_player_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-name',jsonb_build_array(_target_player_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp(_player_id character varying, _guild_id character varying, _target_player_id character varying, _pfp character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-pfp',jsonb_build_array(_target_player_id, _pfp),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp_cr_attributes(_player_id character varying, _guild_id character varying, _target_player_id character varying, _pfp_cr_attributes character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-pfp-cr-attributes',jsonb_build_array(_target_player_id, _pfp_cr_attributes),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_name(_player_id character varying, _guild_id character varying, _substation_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','substation-update-name',jsonb_build_array(_substation_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_pfp(_player_id character varying, _guild_id character varying, _substation_id character varying, _pfp character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','substation-update-pfp',jsonb_build_array(_substation_id, _pfp),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_substation_id(_player_id character varying, _guild_id character varying, _entry_substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,65536,'structs','guild-update-entry-substation-id',jsonb_build_array( _guild_id, _entry_substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_name(_player_id character varying, _guild_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,4,'structs','guild-update-name',jsonb_build_array(_guild_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_pfp(_player_id character varying, _guild_id character varying, _pfp character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,4,'structs','guild-update-pfp',jsonb_build_array(_guild_id, _pfp),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_planet_update_name(_player_id character varying, _planet_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_planet_id,4,'structs','planet-update-name',jsonb_build_array(_planet_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_player_update_name(_player_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-name',jsonb_build_array(_player_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp(_player_id character varying, _pfp character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-pfp',jsonb_build_array(_player_id, _pfp),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp_cr_attributes(_player_id character varying, _pfp_cr_attributes character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-pfp-cr-attributes',jsonb_build_array(_player_id, _pfp_cr_attributes),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.authorized_accounts_v022(_tx_id integer)
 RETURNS TABLE(account_id integer, address character varying, status signer_account_status)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT a.id,a.address,a.status
    FROM signer.tx t
    JOIN signer.role r ON r.player_id=t.requested_player_id AND r.status='ready'
    JOIN signer.account a ON a.role_id=r.id
    JOIN structs.player_address pa ON pa.address=a.address AND pa.status='approved'
        AND pa.player_id=t.requested_player_id
    WHERE t.id=_tx_id AND t.contract='v022-1'
      AND CASE WHEN t.command::text LIKE 'guild-membership-%'
          THEN signer.MEMBERSHIP_CONTEXT_CHECK(t.id,a.address) ELSE TRUE END
      AND CASE WHEN t.command::text LIKE 'allocation-%' OR t.command::text LIKE 'substation-%'
          THEN EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
              AND rule.check_type='energy' AND rule.object_id=t.object_id) ELSE TRUE END
      AND (t.command<>'address-register' OR signer.REGISTRATION_CONTEXT_CHECK(t.id))
      AND (t.command NOT IN ('address-revoke','player-update-primary-address') OR signer.ADDRESS_MANAGEMENT_CHECK(t.id))
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type='energy' THEN
              rule.object_id=t.object_id AND signer.ENERGY_CONTEXT_CHECK(t.id,a.address)
          WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK ((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text, 'permission-address'::text, 'permission-object'::text, 'energy'::text])));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK ((((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text])) AND ((subject_id)::text = ''::text) AND (operation = ''::text) AND (permission > 0)) OR ((check_type = ANY (ARRAY['permission-address'::text, 'permission-object'::text])) AND (operation = ANY (ARRAY['grant'::text, 'set'::text, 'revoke'::text])) AND ((operation = 'set'::text) OR (permission > 0)) AND (((check_type = 'permission-address'::text) AND ((subject_id)::text = ''::text)) OR ((check_type = 'permission-object'::text) AND ((subject_id)::text ~ '^1-[1-9][0-9]*$'::text)))) OR ((check_type = 'energy'::text) AND (permission = 0) AND ((subject_id)::text = ''::text) AND (operation = ''::text))));
DROP FUNCTION signer.CREATE_COSMETIC_TRANSACTION_V022(VARCHAR,structs.signer_tx_type,VARCHAR,VARCHAR,VARCHAR);
DROP FUNCTION signer.COSMETIC_CONTEXT_CHECK(INTEGER);
COMMIT;
