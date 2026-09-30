-- Verify structs-pg:function-unit-display-format-20260930-zero-display-unit on pg

BEGIN;

    DO $$
    DECLARE
        c record;
        got text;
    BEGIN
        FOR c IN
            SELECT * FROM (VALUES
                ('0'::numeric,                   'ualpha',            '0g'),
                ('0',                            'ualpha.infused',    '0g'),
                ('0',                            'ualpha.defusing',   '0g'),
                ('1',                            'ualpha',            '1μg'),
                ('0',                            'milliwatt',         '0W'),
                ('1',                            'milliwatt',         '1mW'),
                ('0',                            'ore',               '0g'),
                ('0',                            'uguild.verify-none', '0guild.verify-none')
            ) AS t(amount, denom, expected)
        LOOP
            got := structs.UNIT_DISPLAY_FORMAT(c.amount, c.denom);
            IF got IS DISTINCT FROM c.expected THEN
                RAISE EXCEPTION 'UNIT_DISPLAY_FORMAT(%, %) = %, expected %', c.amount, c.denom, got, c.expected;
            END IF;
        END LOOP;

        IF structs.UNIT_DISPLAY_FORMAT(NULL, 'ualpha') IS NOT NULL THEN
            RAISE EXCEPTION 'UNIT_DISPLAY_FORMAT(NULL, ualpha) should be NULL';
        END IF;
    END
    $$;

ROLLBACK;
