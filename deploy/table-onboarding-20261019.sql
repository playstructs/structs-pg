-- Deploy structs-pg:table-onboarding-20261019 to pg
--
-- Insert-only onboarding telemetry. The webapp writes onboarding_session
-- once, then inserts onboarding_progress as each signup or tutorial step is
-- reached or skipped. onboarding_step is the catalog for a tutorial design;
-- tutorial-4 is loaded here. See docs/onboarding-telemetry-handoff.md.
--
-- signup.recovery_key_faq is step_order 0. It is not on the linked list:
-- previous_step_key is null and no row points at it. The signup main line
-- is step_order 1..12, from signup.connecting to signup.employee_record.

BEGIN;

    CREATE TABLE structs.onboarding_step (
        content_version   CHARACTER VARYING NOT NULL,
        phase             CHARACTER VARYING NOT NULL,
        step_order        SMALLINT NOT NULL,
        step_key          CHARACTER VARYING NOT NULL,
        previous_step_key CHARACTER VARYING,
        PRIMARY KEY (content_version, phase, step_order),
        UNIQUE (content_version, step_key),
        FOREIGN KEY (content_version, previous_step_key)
            REFERENCES structs.onboarding_step (content_version, step_key)
            DEFERRABLE INITIALLY DEFERRED,
        CHECK (phase IN ('signup', 'tutorial'))
    );

    COMMENT ON TABLE structs.onboarding_step IS
        'Onboarding step catalog, one linked list per (content_version, phase). previous_step_key is the main-line predecessor. The webapp does not write this table.';

    CREATE TABLE structs.onboarding_session (
        session_id       UUID PRIMARY KEY,
        browser_id       UUID NOT NULL,
        interface_name   CHARACTER VARYING NOT NULL,
        guild_id         CHARACTER VARYING,
        content_version  CHARACTER VARYING NOT NULL,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    COMMENT ON TABLE structs.onboarding_session IS
        'One onboarding run, inserted once when signup starts. Identity that arrives later is not written here.';

    CREATE TABLE structs.onboarding_progress (
        session_id   UUID NOT NULL REFERENCES structs.onboarding_session (session_id),
        step_key     CHARACTER VARYING NOT NULL,
        kind         CHARACTER VARYING NOT NULL,
        player_id    CHARACTER VARYING,
        recorded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (session_id, step_key, kind),
        CHECK (kind IN ('reached', 'skipped'))
    );

    COMMENT ON TABLE structs.onboarding_progress IS
        'Insert-only onboarding events. kind is reached or skipped. player_id is set only on the signup.employee_record reached row.';
    COMMENT ON COLUMN structs.onboarding_progress.recorded_at IS
        'Server clock. The latest value for a session is the last time that session was seen.';

    CREATE INDEX onboarding_progress_player_idx
        ON structs.onboarding_progress (player_id)
        WHERE player_id IS NOT NULL;

    -- tutorial-4. Inserted in one statement; the previous_step_key foreign
    -- key is deferred to commit.
    INSERT INTO structs.onboarding_step
        (content_version, phase, step_order, step_key, previous_step_key)
    VALUES
        ('tutorial-4', 'signup',  0, 'signup.recovery_key_faq',        NULL),
        ('tutorial-4', 'signup',  1, 'signup.connecting',               NULL),
        ('tutorial-4', 'signup',  2, 'signup.connected',                'signup.connecting'),
        ('tutorial-4', 'signup',  3, 'signup.incoming_call',            'signup.connected'),
        ('tutorial-4', 'signup',  4, 'signup.hr_greeting',              'signup.incoming_call'),
        ('tutorial-4', 'signup',  5, 'signup.orientation_brief',        'signup.hr_greeting'),
        ('tutorial-4', 'signup',  6, 'signup.profile',                  'signup.orientation_brief'),
        ('tutorial-4', 'signup',  7, 'signup.profile_confirmed',        'signup.profile'),
        ('tutorial-4', 'signup',  8, 'signup.recovery_key_intro',       'signup.profile_confirmed'),
        ('tutorial-4', 'signup',  9, 'signup.recovery_key_create',      'signup.recovery_key_intro'),
        ('tutorial-4', 'signup', 10, 'signup.recovery_key_confirm',     'signup.recovery_key_create'),
        ('tutorial-4', 'signup', 11, 'signup.submit',                   'signup.recovery_key_confirm'),
        ('tutorial-4', 'signup', 12, 'signup.employee_record',          'signup.submit'),

        ('tutorial-4', 'tutorial',  1, 'orientation.tutorial_offer',            NULL),
        ('tutorial-4', 'tutorial',  2, 'tutorial.loading',                      'orientation.tutorial_offer'),
        ('tutorial-4', 'tutorial',  3, 'tutorial.intro.welcome',                'tutorial.loading'),
        ('tutorial-4', 'tutorial',  4, 'tutorial.intro.alpha_base',             'tutorial.intro.welcome'),
        ('tutorial-4', 'tutorial',  5, 'tutorial.intro.alpha_ore',              'tutorial.intro.alpha_base'),
        ('tutorial-4', 'tutorial',  6, 'tutorial.intro.refinery',               'tutorial.intro.alpha_ore'),
        ('tutorial-4', 'tutorial',  7, 'tutorial.intro.ore_reserves',           'tutorial.intro.refinery'),
        ('tutorial-4', 'tutorial',  8, 'tutorial.intro.ore_thefts',             'tutorial.intro.ore_reserves'),
        ('tutorial-4', 'tutorial',  9, 'tutorial.intro.cmd_ship',               'tutorial.intro.ore_thefts'),
        ('tutorial-4', 'tutorial', 10, 'tutorial.intro.cmd_ship_warning',       'tutorial.intro.cmd_ship'),
        ('tutorial-4', 'tutorial', 11, 'tutorial.raid.raiders_attack',          'tutorial.intro.cmd_ship_warning'),
        ('tutorial-4', 'tutorial', 12, 'tutorial.raid.planetary_defenses',      'tutorial.raid.raiders_attack'),
        ('tutorial-4', 'tutorial', 13, 'tutorial.raid.inspect_defenses',        'tutorial.raid.planetary_defenses'),
        ('tutorial-4', 'tutorial', 14, 'tutorial.raid.cmd_ship_protects',       'tutorial.raid.inspect_defenses'),
        ('tutorial-4', 'tutorial', 15, 'tutorial.raid.cmd_ship_strike',         'tutorial.raid.cmd_ship_protects'),
        ('tutorial-4', 'tutorial', 16, 'tutorial.raid.cmd_ship_destroyed',      'tutorial.raid.cmd_ship_strike'),
        ('tutorial-4', 'tutorial', 17, 'tutorial.raid.breach_countdown',        'tutorial.raid.cmd_ship_destroyed'),
        ('tutorial-4', 'tutorial', 18, 'tutorial.rebuild.select_command_tile',  'tutorial.raid.breach_countdown'),
        ('tutorial-4', 'tutorial', 19, 'tutorial.rebuild.open_deploy',          'tutorial.rebuild.select_command_tile'),
        ('tutorial-4', 'tutorial', 20, 'tutorial.rebuild.deploy_cmd_ship',      'tutorial.rebuild.open_deploy'),
        ('tutorial-4', 'tutorial', 21, 'tutorial.rebuild.battery',              'tutorial.rebuild.deploy_cmd_ship'),
        ('tutorial-4', 'tutorial', 22, 'tutorial.defend.unprotected',           'tutorial.rebuild.battery'),
        ('tutorial-4', 'tutorial', 23, 'tutorial.defend.select_tank',           'tutorial.defend.unprotected'),
        ('tutorial-4', 'tutorial', 24, 'tutorial.defend.press_defend',          'tutorial.defend.select_tank'),
        ('tutorial-4', 'tutorial', 25, 'tutorial.defend.choose_sam_launcher',   'tutorial.defend.press_defend'),
        ('tutorial-4', 'tutorial', 26, 'tutorial.defend.icon_legend',           'tutorial.defend.choose_sam_launcher'),
        ('tutorial-4', 'tutorial', 27, 'tutorial.defend.cmd_ship_delay',        'tutorial.defend.icon_legend'),
        ('tutorial-4', 'tutorial', 28, 'tutorial.first_attack.goal',            'tutorial.defend.cmd_ship_delay'),
        ('tutorial-4', 'tutorial', 29, 'tutorial.first_attack.select_tank',     'tutorial.first_attack.goal'),
        ('tutorial-4', 'tutorial', 30, 'tutorial.first_attack.choose_rail_gun', 'tutorial.first_attack.select_tank'),
        ('tutorial-4', 'tutorial', 31, 'tutorial.first_attack.choose_target',   'tutorial.first_attack.choose_rail_gun'),
        ('tutorial-4', 'tutorial', 32, 'tutorial.first_attack.combat',          'tutorial.first_attack.choose_target'),
        ('tutorial-4', 'tutorial', 33, 'tutorial.first_attack.went_poorly',     'tutorial.first_attack.combat'),
        ('tutorial-4', 'tutorial', 34, 'tutorial.first_attack.blocked',         'tutorial.first_attack.went_poorly'),
        ('tutorial-4', 'tutorial', 35, 'tutorial.first_attack.counter_attacks', 'tutorial.first_attack.blocked'),
        ('tutorial-4', 'tutorial', 36, 'tutorial.first_attack.defender_first',  'tutorial.first_attack.counter_attacks'),
        ('tutorial-4', 'tutorial', 37, 'tutorial.first_attack.avoid_counters',  'tutorial.first_attack.defender_first'),
        ('tutorial-4', 'tutorial', 38, 'tutorial.first_attack.battlegrounds',   'tutorial.first_attack.avoid_counters'),
        ('tutorial-4', 'tutorial', 39, 'tutorial.first_attack.rail_gun_land_only', 'tutorial.first_attack.battlegrounds'),
        ('tutorial-4', 'tutorial', 40, 'tutorial.bomber.select_bomber',         'tutorial.first_attack.rail_gun_land_only'),
        ('tutorial-4', 'tutorial', 41, 'tutorial.bomber.choose_weapon',         'tutorial.bomber.select_bomber'),
        ('tutorial-4', 'tutorial', 42, 'tutorial.bomber.choose_target',         'tutorial.bomber.choose_weapon'),
        ('tutorial-4', 'tutorial', 43, 'tutorial.bomber.combat',                'tutorial.bomber.choose_target'),
        ('tutorial-4', 'tutorial', 44, 'tutorial.bomber.success',               'tutorial.bomber.combat'),
        ('tutorial-4', 'tutorial', 45, 'tutorial.bomber.close_to_victory',      'tutorial.bomber.success'),
        ('tutorial-4', 'tutorial', 46, 'tutorial.free_play.destroy_cmd_ship',   'tutorial.bomber.close_to_victory'),
        ('tutorial-4', 'tutorial', 47, 'tutorial.new_cmd_ship.raiders_repelled','tutorial.free_play.destroy_cmd_ship'),
        ('tutorial-4', 'tutorial', 48, 'tutorial.new_cmd_ship.arriving',        'tutorial.new_cmd_ship.raiders_repelled'),
        ('tutorial-4', 'tutorial', 49, 'tutorial.new_cmd_ship.arrival',         'tutorial.new_cmd_ship.arriving'),
        ('tutorial-4', 'tutorial', 50, 'tutorial.new_cmd_ship.secure',          'tutorial.new_cmd_ship.arrival'),
        ('tutorial-4', 'tutorial', 51, 'tutorial.end.completed',                'tutorial.new_cmd_ship.secure'),
        ('tutorial-4', 'tutorial', 52, 'tutorial.end.certified',                'tutorial.end.completed'),
        ('tutorial-4', 'tutorial', 53, 'tutorial.end.ftl_jump',                 'tutorial.end.certified');

COMMIT;
