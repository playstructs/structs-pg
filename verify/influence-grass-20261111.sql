BEGIN;
SELECT frame_id,subject,payload FROM structs.influence_grass_frame WHERE false;
SELECT * FROM structs.influence_player_score_change WHERE false;
SELECT 1/(to_regprocedure('structs.influence_grass_flush(text,bigint,text,timestamptz)') IS NOT NULL)::int;
SELECT 1/(count(*)=1)::int FROM pg_trigger WHERE tgrelid='structs.influence_published_build'::regclass AND tgname='influence_grass_published';
SELECT 1/(count(*)=0)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
 LATERAL aclexplode(p.proacl) a WHERE n.nspname='structs' AND p.proname LIKE 'influence_grass_%' AND a.grantee=0;
ROLLBACK;
