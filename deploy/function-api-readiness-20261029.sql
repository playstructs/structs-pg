-- Deploy structs-pg:function-api-readiness-20261029 to pg
BEGIN;
-- Call in the same statement/snapshot as the data it describes. The small
-- projection catalog is read once; no balance/history scan or RPC is involved.
CREATE FUNCTION structs.api_readiness(p_models TEXT[] DEFAULT ARRAY[]::TEXT[])
RETURNS TABLE (
    height TEXT, chain_id TEXT, indexed_height TEXT, observed_tip TEXT,
    protocol TEXT, observed_protocol TEXT, activation_height TEXT,
    api_contract TEXT, cache_epoch TEXT, inventory_authority TEXT,
    required_models TEXT[], models JSONB, source_time TIMESTAMPTZ,
    data_ready BOOLEAN, transaction_ready BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $BODY$
WITH cursor_row AS (
    SELECT * FROM sync_state.sync_cursor WHERE (SELECT count(*) FROM sync_state.sync_cursor)=1
), block_row AS (
    SELECT * FROM structs.current_block WHERE (SELECT count(*) FROM structs.current_block)=1
), context AS (
    SELECT c.chain_id::text,c.last_height,c.last_block_time,c.status,
           GREATEST(c.tip_height,b.tip_height) AS tip,
           COALESCE(c.chain_id=b.chain AND c.last_height=b.height AND c.last_height>0
               AND c.last_block_time IS NOT NULL,FALSE) AS consistent,
           (SELECT r.inventory_authority FROM structs.api_refresh_state r WHERE r.model='inventory') AS authority
    FROM (VALUES (1)) seed(n) LEFT JOIN cursor_row c ON TRUE LEFT JOIN block_row b ON TRUE
), active AS (
    SELECT *, CASE WHEN chain_id='structstestnet-111' AND last_height>0
                   THEN CASE WHEN last_height>=3353000 THEN 'v0.22.0' ELSE 'v0.21.0' END END AS era,
              CASE WHEN chain_id='structstestnet-111' AND tip>0
                   THEN CASE WHEN tip>=3353000 THEN 'v0.22.0' ELSE 'v0.21.0' END END AS tip_era
    FROM context
), boundary AS (
    SELECT *, COALESCE(consistent AND era IS NOT NULL
        AND (era='v0.21.0' OR authority='current-claims-v1'),FALSE) AS ready
    FROM active
), requested AS (SELECT DISTINCT unnest(p_models) AS model), names AS (
    SELECT model FROM structs.api_refresh_state UNION SELECT model FROM requested
), states AS (
    SELECT n.model,r.source_height,r.source_time,
           COALESCE(b.ready AND r.source_height=b.last_height AND r.source_time=b.last_block_time,FALSE) AS ready
    FROM names n LEFT JOIN structs.api_refresh_state r USING(model) CROSS JOIN boundary b
), required AS (
    SELECT count(*) AS n,count(s.source_height) AS available,MIN(s.source_height) AS minimum_height,
           COALESCE(bool_and(s.ready),TRUE) AS ready
    FROM requested q LEFT JOIN states s ON s.model=q.model
), result AS (
    SELECT b.*,r.n,r.available,r.minimum_height,
           b.ready AND r.ready AND r.n=r.available AND p_models IS NOT NULL
               AND NOT EXISTS(SELECT 1 FROM requested WHERE model IS NULL OR model='') AS all_ready
    FROM boundary b CROSS JOIN required r
)
SELECT CASE WHEN NOT consistent THEN NULL WHEN n=0 THEN last_height::text
            WHEN n=available THEN minimum_height::text END,
       chain_id,last_height::text,tip::text,era,tip_era,
       CASE WHEN chain_id='structstestnet-111' THEN '3353000' END,
       'structs-api-v022-1','structs-api-v022-1:' || COALESCE(era,'unknown'),authority,
       ARRAY(SELECT model FROM requested ORDER BY model),
       COALESCE((SELECT jsonb_object_agg(model,jsonb_build_object(
           'height',source_height::text,'source_time',source_time,'ready',ready))
           FROM states WHERE model IS NOT NULL),'{}'::jsonb),
       CASE WHEN all_ready THEN last_block_time END,all_ready,
       COALESCE(all_ready AND status='current' AND tip>=last_height AND era=tip_era,FALSE)
FROM result;
$BODY$;
REVOKE ALL ON FUNCTION structs.api_readiness(TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION structs.api_readiness(TEXT[]) TO structs_webapp,structs_indexer;
COMMENT ON FUNCTION structs.api_readiness(TEXT[]) IS
    'Indexed protocol and exact model watermarks for a consistent response snapshot. Missing required models never borrow the cursor height. Transaction readiness uses observed tip only; signers must independently verify current chain/height.';
COMMIT;
