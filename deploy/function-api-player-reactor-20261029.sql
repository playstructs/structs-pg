-- Deploy structs-pg:function-api-player-reactor-20261029 to pg
BEGIN;
-- Scoped current ownership and exact per-validator evidence, never ledger
-- history or a row selected arbitrarily from a player's several addresses.
CREATE FUNCTION structs.api_player_reactor(p_player_id TEXT)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $BODY$
WITH context AS (
    SELECT p.id,g.primary_reactor_id,g.join_infusion_minimum_p,
        r.validator,r.default_commission,v.address AS vault_address,
        m.chain_id,m.indexed_height,m.data_ready,m.protocol
    FROM structs.player p JOIN structs.guild g ON g.id=p.guild_id
    LEFT JOIN structs.reactor r ON r.id=g.primary_reactor_id
    LEFT JOIN structs.vault v ON v.owner_id=p.id
    CROSS JOIN structs.api_readiness(ARRAY['inventory']) m
    WHERE p.id=p_player_id
), addresses AS MATERIALIZED (
    -- Inspect one extra address to detect overflow, without publishing a
    -- truncated total. This is a read bound, not a transaction message limit.
    SELECT a.address,a.is_vault FROM structs.asset_owner a
    WHERE a.owner_type='player' AND a.owner_id=p_player_id LIMIT 1025
), coverage AS (
    SELECT count(*)<=1024 AS bounded,count(*)>0 AS has_addresses FROM addresses
), positions AS MATERIALIZED (
    SELECT a.address,a.is_vault,s.source_height,
        COALESCE(s.complete,FALSE) AS native_ready,
        CASE WHEN s.complete THEN COALESCE(n.bonded,0) END AS bonded,
        CASE WHEN s.complete THEN COALESCE(n.unbonding,0) END AS unbonding,
        CASE WHEN s.complete THEN COALESCE(n.unbonding_entries,0) END AS unbonding_entries,
        i.fuel_p AS stored_fuel_p,i.defusing_p AS stored_defusing_p,
        i.power_p,i.ratio_p,i.commission,i.created_at,i.updated_at,
        i.destination_id IS NOT NULL AS has_infusion,
        COALESCE(NULLIF(i.owner_id,''),i.player_id) AS recorded_owner_id,
        CASE WHEN i.destination_id IS NULL THEN TRUE ELSE COALESCE(
            COALESCE(NULLIF(i.owner_id,''),i.player_id)=c.id AND i.destination_type='reactor'
            AND i.power_p>=0 AND i.power_p<'Infinity'::numeric AND i.power_p=trunc(i.power_p)
            AND i.commission>=0 AND i.commission<=1,FALSE) END AS power_valid
    FROM context c CROSS JOIN addresses a CROSS JOIN coverage b
    LEFT JOIN sync_state.native_staking_position_state s ON s.chain_id=c.chain_id AND s.address=a.address
    LEFT JOIN sync_state.native_staking_position n ON n.chain_id=c.chain_id AND n.address=a.address AND n.validator=c.validator
    LEFT JOIN structs.infusion i ON i.destination_id=c.primary_reactor_id AND i.address=a.address
    WHERE b.bounded
), powered AS (
    SELECT *,CASE WHEN power_valid THEN COALESCE(power_p,0) END AS gross_power,
        -- Cosmos LegacyDec.RoundInt uses ties-to-even, per infusion. PostgreSQL
        -- round(numeric) instead rounds ties away from zero.
        CASE WHEN power_valid THEN COALESCE(power_p-(floor(power_p*commission)+
            CASE WHEN power_p*commission-floor(power_p*commission)>0.5
                OR (power_p*commission-floor(power_p*commission)=0.5
                    AND mod(floor(power_p*commission),2)=1) THEN 1 ELSE 0 END),0) END AS owner_power
    FROM positions
), totals AS (
    SELECT COALESCE(bool_and(native_ready),FALSE) AS native_ready,
        COALESCE(bool_and(power_valid),FALSE) AS power_valid,
        COALESCE(sum(bonded),0) AS bonded,COALESCE(sum(unbonding),0) AS unbonding,
        COALESCE(sum(gross_power),0) AS gross_power,COALESCE(sum(owner_power),0) AS owner_power,
        MIN(source_height) AS minimum_height,MIN(created_at) AS created_at,MAX(updated_at) AS updated_at
    FROM powered
), readiness AS (
    SELECT c.*,t.*,b.bounded,
        c.data_ready AND c.protocol='v0.22.0' AND c.validator IS NOT NULL
            AND b.bounded AND b.has_addresses AS base_ready,
        c.vault_address IS NOT NULL AS vault_indexed
    FROM context c CROSS JOIN totals t CROSS JOIN coverage b
), result AS (
    SELECT *,base_ready AND vault_indexed AND native_ready AS balances_ready,
        base_ready AND power_valid AS power_ready FROM readiness
)
SELECT jsonb_build_object(
    'destination_id',primary_reactor_id,'destination_type','reactor','address',NULL,
    'player_id',id,'owner_id',id,'vault_address',vault_address,'validator',validator,
    'fuel_p',CASE WHEN balances_ready THEN bonded::text END,
    'defusing_p',CASE WHEN balances_ready THEN unbonding::text END,
    'fuel',CASE WHEN balances_ready THEN floor(bonded/1000000)::text END,
    'defusing',CASE WHEN balances_ready THEN floor(unbonding/1000000)::text END,
    'power_p',CASE WHEN power_ready THEN gross_power::text END,
    'owner_power_p',CASE WHEN power_ready THEN owner_power::text END,
    'power',CASE WHEN power_ready THEN floor(gross_power/1000)::text END,
    'owner_power',CASE WHEN power_ready THEN floor(owner_power/1000)::text END,
    'ratio','1000','ratio_p','1','commission',floor(default_commission*100)::text,
    'preview_commission',default_commission::text,
    'join_infusion_minimum',floor(join_infusion_minimum_p/1000000)::text,
    'join_infusion_minimum_p',join_infusion_minimum_p::text,
    'created_at',created_at,'updated_at',updated_at,
    'positions_meta',jsonb_build_object('height',indexed_height,'complete',balances_ready,
        'power_ready',power_ready,'minimum_source_height',minimum_height::text,
        'eligibility_checked',FALSE,'address_limit',1024,
        'reason',CASE WHEN NOT data_ready OR protocol IS DISTINCT FROM 'v0.22.0' THEN 'snapshot_unavailable'
            WHEN NOT bounded THEN 'address_limit' WHEN validator IS NULL THEN 'reactor_unavailable'
            WHEN NOT vault_indexed THEN 'vault_unindexed' WHEN NOT native_ready THEN 'native_unavailable'
            WHEN NOT power_valid THEN 'power_unavailable' END),
    'positions',COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'address',p.address,'is_vault',p.is_vault,'owner_id',r.id,
        'recorded_owner_id',p.recorded_owner_id,'validator',r.validator,
        'native_ready',r.base_ready AND p.native_ready,'source_height',p.source_height::text,
        'fuel_p',CASE WHEN r.base_ready THEN p.bonded::text END,
        'defusing_p',CASE WHEN r.base_ready THEN p.unbonding::text END,
        'unbonding_entries',CASE WHEN r.base_ready THEN p.unbonding_entries END,
        'power_p',CASE WHEN r.base_ready THEN p.gross_power::text END,
        'owner_power_p',CASE WHEN r.base_ready THEN p.owner_power::text END,
        'power_ready',r.base_ready AND p.power_valid,
        'stored_fuel_p',p.stored_fuel_p::text,'stored_defusing_p',p.stored_defusing_p::text,
        'ratio_p',p.ratio_p::text,'commission',p.commission::text)
        ORDER BY p.is_vault DESC,p.address COLLATE "C") FROM powered p),'[]'::jsonb))
FROM result r;
$BODY$;
REVOKE ALL ON FUNCTION structs.api_player_reactor(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION structs.api_player_reactor(TEXT) TO structs_webapp,structs_indexer;
COMMENT ON FUNCTION structs.api_player_reactor(TEXT) IS
    'Post-v0.22 player positions on the current guild reactor. Raw amounts are exact strings. Current address ownership, native balances and per-infusion applied power remain distinct. Readiness is indexed evidence, never live staking or signing eligibility.';
COMMIT;
