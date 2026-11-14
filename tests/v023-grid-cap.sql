-- Run against an isolated database after grid-connection-capacity-maximum-20261114.
BEGIN;
DO $$
DECLARE before_tid tid; after_tid tid; bad text; stored numeric; label text;
BEGIN
    PERFORM cache.handle_event_grid('{"attributeId":"15-4-999823","value":"18446744073709551615"}');
    SELECT val,attribute_type,ctid INTO stored,label,before_tid FROM structs.grid WHERE id='15-4-999823';
    IF stored IS DISTINCT FROM 18446744073709551615::numeric OR label IS DISTINCT FROM 'connectionCapacityMaximum' THEN
        RAISE EXCEPTION 'cap lost precision or label';
    END IF;
    PERFORM cache.handle_event_grid('{"attributeId":"15-4-999823","value":"18446744073709551615"}');
    SELECT ctid INTO after_tid FROM structs.grid WHERE id='15-4-999823';
    IF before_tid <> after_tid THEN RAISE EXCEPTION 'identical replay rewrote row'; END IF;
    UPDATE structs.grid SET attribute_type='wrong' WHERE id='15-4-999823';
    PERFORM cache.handle_event_grid('{"attributeId":"15-4-999823","value":"18446744073709551615"}');
    IF (SELECT attribute_type FROM structs.grid WHERE id='15-4-999823') <> 'connectionCapacityMaximum' THEN
        RAISE EXCEPTION 'unchanged-value label repair failed';
    END IF;
    FOREACH bad IN ARRAY ARRAY['-1','1.5','18446744073709551616','invalid'] LOOP
        BEGIN
            PERFORM cache.handle_event_grid(jsonb_build_object('attributeId','15-4-999823','value',bad));
            RAISE EXCEPTION 'accepted invalid cap %', bad USING ERRCODE='ZX001';
        EXCEPTION WHEN SQLSTATE 'ZX001' THEN RAISE; WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    PERFORM cache.handle_event_grid('{"attributeId":"15-4-999823","value":"0"}');
    IF (SELECT val FROM structs.grid WHERE id='15-4-999823') <> 0 THEN RAISE EXCEPTION 'zero cap lost'; END IF;
    PERFORM cache.handle_event_grid('{"attributeId":"15-4-999823","value":""}');
    IF EXISTS (SELECT 1 FROM structs.grid WHERE id='15-4-999823') THEN RAISE EXCEPTION 'delete failed'; END IF;
END $$;
ROLLBACK;
