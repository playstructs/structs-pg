-- Deploy structs-pg:table-banned-word to pg

BEGIN;

    CREATE  TABLE structs.banned_word (
       value       TEXT PRIMARY KEY,
       created_at   TIMESTAMPTZ DEFAULT NOW(),
       updated_at   TIMESTAMPTZ DEFAULT NOW()
    );

    INSERT INTO structs.banned_word VALUES
        -- I'm sure this list will get longer
        -- but Guilds can individually set their own standard.

        -- mean shit
        ('nigger', NOW(), NOW()),
        ('nigga', NOW(), NOW()),
        ('faggot', NOW(), NOW()),
        ('fag', NOW(), NOW()),
        ('cunt', NOW(), NOW()),

        -- dumb shit
        ('nazi', NOW(), NOW()),
        ('hitler', NOW(), NOW()),
        ('isis', NOW(), NOW()),
        ('kkk', NOW(), NOW()),
        ('pedo', NOW(), NOW());


COMMIT;
