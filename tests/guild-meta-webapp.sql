-- Run after guild-meta-webapp-20261123; all fixture writes roll back.
BEGIN;

SELECT structs.guild_metadata_update('__webapp_test__',
    '{"guild":{"name":"Webapp test","webapp":"first.example","services":{"guild_api":"https://api.example/"}}}'::jsonb, true);
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__webapp_test__'
        AND webapp = 'first.example'
        AND services->>'guild_api' = 'https://api.example/' AND this_infrastructure) THEN
        RAISE EXCEPTION 'webapp insert or service preservation failed';
    END IF;
END $$;

SELECT structs.guild_metadata_update('__webapp_test__',
    '{"guild":{"webapp":"https://second.example/"}}'::jsonb, false);
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__webapp_test__'
        AND webapp = 'https://second.example/' AND this_infrastructure) THEN
        RAISE EXCEPTION 'webapp update or infrastructure preservation failed';
    END IF;
END $$;

SELECT structs.guild_metadata_update('__webapp_test__',
    '{"guild":{"webapp":null}}'::jsonb, false);
DO $$ BEGIN
    IF EXISTS (SELECT FROM structs.guild_meta WHERE id = '__webapp_test__' AND webapp IS NOT NULL) THEN
        RAISE EXCEPTION 'JSON null must clear webapp';
    END IF;
END $$;

SELECT structs.guild_metadata_update('__webapp_test__',
    '{"guild":{"webapp":"https://third.example/"}}'::jsonb, false);
SELECT structs.guild_metadata_update('__webapp_test__', '{"guild":{}}'::jsonb, false);
DO $$ BEGIN
    IF EXISTS (SELECT FROM structs.guild_meta WHERE id = '__webapp_test__' AND webapp IS NOT NULL) THEN
        RAISE EXCEPTION 'missing guild.webapp must clear webapp';
    END IF;
END $$;

ROLLBACK;
