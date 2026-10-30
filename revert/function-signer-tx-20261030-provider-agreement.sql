-- Revert structs-pg:function-signer-tx-20261030-provider-agreement from pg
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1'
        AND (command::text LIKE 'provider-%' OR command::text LIKE 'agreement-%')) THEN
        RAISE EXCEPTION 'versioned provider/agreement requests exist; retain their wrapper contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_decrease(_player_id character varying, _agreement_id character varying, _capacity_decrease numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_agreement_id,4,'structs','agreement-capacity-decrease',jsonb_build_array( _agreement_id, _capacity_decrease),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_increase(_player_id character varying, _agreement_id character varying, _capacity_increase numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_agreement_id,4,'structs','agreement-capacity-increase',jsonb_build_array( _agreement_id, _capacity_increase),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_agreement_close(_player_id character varying, _agreement_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_agreement_id,4,'structs','agreement-close',jsonb_build_array( _agreement_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_agreement_duration_increase(_player_id character varying, _agreement_id character varying, _duration_increase numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_agreement_id,4,'structs','agreement-duration-increase',jsonb_build_array( _agreement_id, _duration_increase),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_agreement_open(_player_id character varying, _provider_id character varying, _duration numeric, _capacity numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,262144,'structs','agreement-open',jsonb_build_array(_provider_id, _duration, _capacity),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_create(_player_id character varying, _substation_id character varying, _rate_denom character varying, _rate_amount numeric, _access_policy character varying, _provider_penalty numeric, _consumer_penalty numeric, _capacity_min numeric, _capacity_max numeric, _duration_min numeric, _duration_max numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,262144,'structs','provider-create',jsonb_build_array(_substation_id, _rate_amount || _rate_denom, _access_policy, _provider_penalty, _consumer_penalty, _capacity_min, _capacity_max, _duration_min, _duration_max),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_delete(_player_id character varying, _provider_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,8,'structs','provider-delete',jsonb_build_array( _provider_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_update_access_policy(_player_id character varying, _provider_id character varying, _access_policy character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-update-access-policy',jsonb_build_array( _provider_id, _access_policy),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_maximum(_player_id character varying, _provider_id character varying, _new_maximum_capacity numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-update-capacity-maximum',jsonb_build_array(_provider_id, _new_maximum_capacity),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_minimum(_player_id character varying, _provider_id character varying, _new_minimum_capacity numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-update-capacity-minimum',jsonb_build_array(_provider_id, _new_minimum_capacity),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_maximum(_player_id character varying, _provider_id character varying, _new_maximum_duration numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-update-duration-maximum',jsonb_build_array( _provider_id, _new_maximum_duration),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_minimum(_player_id character varying, _provider_id character varying, _new_minimum_duration numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,4,'structs','provider-update-duration-minimum',jsonb_build_array( _provider_id, _new_minimum_duration),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_provider_withdraw_balance(_player_id character varying, _provider_id character varying, _destination_address character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_provider_id,131072,'structs','provider-withdraw-balance',jsonb_build_array(_provider_id, _destination_address),'{}');
    END
    $function$
;

DROP FUNCTION signer.tx_agreement_open(CHARACTER VARYING,CHARACTER VARYING,NUMERIC,NUMERIC,CHARACTER VARYING);
DROP FUNCTION signer.tx_provider_create(CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,NUMERIC,CHARACTER VARYING,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,CHARACTER VARYING);
DROP FUNCTION signer.SELECT_ASSET_OWNER(CHARACTER VARYING,CHARACTER VARYING);
DROP FUNCTION signer.PENALTY_ARGUMENT(NUMERIC);
DROP FUNCTION signer.COIN_ARGUMENT(NUMERIC,CHARACTER VARYING,BOOLEAN);
DROP FUNCTION signer.UINT64_ARGUMENT(NUMERIC,TEXT,BOOLEAN);
COMMIT;
