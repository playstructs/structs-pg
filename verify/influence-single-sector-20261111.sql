BEGIN;
SELECT scoring_mode FROM structs.influence_contest WHERE false;
SELECT scoring_mode,sectors_complete FROM structs.influence_standings WHERE false;
SELECT overall_points,sector_rank,tied_for_lead,is_winner FROM structs.influence_ranked_standings WHERE false;
SELECT 1/(to_regprocedure('structs.influence_create_contest(text,bigint,bigint,bigint,text)') IS NOT NULL)::int;
-- Check declared privileges: legacy installations may have superuser app roles.
SELECT 1/(count(*)=0)::int FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
 WHERE p.oid='structs.influence_create_contest(text,bigint,bigint,bigint,text)'::regprocedure
 AND a.grantee IN (0,(SELECT oid FROM pg_roles WHERE rolname='structs_webapp'),
 (SELECT oid FROM pg_roles WHERE rolname='structs_indexer'));
SELECT 1/has_table_privilege('structs_webapp','structs.influence_ranked_standings','SELECT')::int;
SELECT 1/(count(*)=0)::int FROM structs.influence_contest
 WHERE scoring_mode NOT IN ('planet_sectors','single_sector') OR scoring_mode IS NULL;
ROLLBACK;
