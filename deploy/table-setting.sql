-- Deploy structs-pg:table-settings to pg

BEGIN;

CREATE  TABLE structs.setting (
   name        CHARACTER VARYING PRIMARY KEY,
   value       TEXT,
   updated_at   TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO structs.setting VALUES
    ('REACTOR_RATIO','1000',NOW()),
    ('PLAYER_RESUME_CHARGE','666',NOW()),
    ('PLANETARY_SHIELD_BASE','1500', NOW()),
    ('PLAYER_PASSIVE_DRAW','25', NOW()),
    ('PLANET_STARTING_ORE','5', NOW()),
    ('PLANET_STARTING_SLOTS','4', NOW());


COMMIT;
