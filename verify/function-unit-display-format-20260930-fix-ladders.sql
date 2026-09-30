-- Verify structs-pg:function-unit-display-format-20260930-fix-ladders on pg

BEGIN;

    DO $$
    DECLARE
        c record;
        got text;
    BEGIN
        FOR c IN
            SELECT * FROM (VALUES
                ('0'::numeric,                   'ualpha',            '0μg'),
                ('999',                          'ualpha',            '1mg'),
                ('1000000',                      'ualpha',            '1g'),
                ('2500000',                      'ualpha',            '2.5g'),
                ('7572000000',                   'ualpha',            '7.57Kg'),
                ('1000000000000000',             'ualpha',            '1000000Kg'),
                ('10000000000000000',            'ualpha',            '10000000Kg'),
                ('100000000000000000',           'ualpha',            '0.1Tg'),
                ('100000000000000000',           'ualpha.infused',    '0.1Tg'),
                ('1000000000000000000',          'ualpha',            '1Tg'),
                ('99',                           'milliwatt',         '99mW'),
                ('99999',                        'milliwatt',         '100W'),
                ('100000',                       'milliwatt',         '0.1KW'),
                ('6877090',                      'milliwatt',         '6.88KW'),
                ('141426000000',                 'milliwatt',         '141.43MW'),
                ('1000000000000000',             'milliwatt',         '1TW'),
                ('25000000000000000',            'milliwatt',         '25TW'),
                ('-120000',                      'milliwatt',         '-0.12KW'),
                ('999',                          'ore',               '999g'),
                ('1000',                         'ore',               '1Kg'),
                ('100000000000',                 'ore',               '0.1Tg'),
                ('1000000000000',                'ore',               '1Tg')
            ) AS t(amount, denom, expected)
        LOOP
            got := structs.UNIT_DISPLAY_FORMAT(c.amount, c.denom);
            IF got IS DISTINCT FROM c.expected THEN
                RAISE EXCEPTION 'UNIT_DISPLAY_FORMAT(%, %) = %, expected %', c.amount, c.denom, got, c.expected;
            END IF;
        END LOOP;
    END
    $$;

ROLLBACK;
