-- Run after guild-meta-language-20261123; all fixture writes roll back.
BEGIN;
INSERT INTO structs.guild_meta (id) VALUES ('__language_default_test__');
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__language_default_test__' AND language = 'EN') THEN
        RAISE EXCEPTION 'table default must be EN';
    END IF;
END $$;

SELECT structs.guild_metadata_update('__language_test__',
    '{"guild":{"language":"FR","webapp":"https://guild.example/"}}', true);
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__language_test__'
        AND language = 'FR' AND webapp = 'https://guild.example/' AND this_infrastructure) THEN
        RAISE EXCEPTION 'language insert must preserve other metadata';
    END IF;
END $$;

DO $$
DECLARE payload jsonb;
BEGIN
    FOREACH payload IN ARRAY ARRAY[
        '{"guild":{}}'::jsonb,
        '{"guild":{"language":null}}'::jsonb,
        '{"guild":{"language":""}}'::jsonb,
        '{"guild":{"language":"   "}}'::jsonb
    ] LOOP
        PERFORM structs.guild_metadata_update('__language_test__', '{"guild":{"language":"JA"}}', false);
        IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__language_test__' AND language = 'JA') THEN
            RAISE EXCEPTION 'language update failed';
        END IF;
        PERFORM structs.guild_metadata_update('__language_test__', payload, false);
        IF NOT EXISTS (SELECT FROM structs.guild_meta WHERE id = '__language_test__' AND language = 'EN' AND this_infrastructure) THEN
            RAISE EXCEPTION 'missing, null or blank language must reset to EN: %', payload;
        END IF;
    END LOOP;
END $$;
ROLLBACK;
