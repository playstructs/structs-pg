-- Compare every category and detail shape against the shared attribution
-- resolver. Fixtures and notifications roll back with this transaction.
BEGIN;

INSERT INTO structs.planet(id, owner) VALUES ('2-999900001', '1-999900001');
INSERT INTO structs.struct(id, owner) VALUES
    ('5-999900001', '1-999900001'),
    ('5-999900002', '1-999900002'),
    ('5-999900003', '');
INSERT INTO structs.fleet(id, owner) VALUES ('9-999900001', '1-999900001');
INSERT INTO structs.player_object(object_id, player_id) VALUES
    ('5-999900001', '1-999900003'),
    ('5-999900002', ''),
    ('2-999900001', '1-999900002');

CREATE TEMP TABLE activity_expected ON COMMIT DROP AS
SELECT '2026-11-06 00:00:00+00'::timestamptz AS time,
       '2-999900001'::varchar AS planet_id,
       (2000000000 + row_number() OVER ())::integer AS seq,
       category, detail, 999900001::bigint AS block_height
FROM unnest(enum_range(NULL::structs.grass_category)) category
CROSS JOIN (VALUES
    ('{}'::jsonb), ('null'::jsonb), (NULL::jsonb), ('[]'::jsonb),
    ('{"struct_id":null}'::jsonb), ('{"struct_id":""}'::jsonb),
    ('{"struct_id":"5-999900001"}'::jsonb),
    ('{"struct_id":"5-999900002"}'::jsonb),
    ('{"struct_id":"5-999900003"}'::jsonb),
    ('{"struct_id":"5-999900004"}'::jsonb),
    ('{"planet_id":"2-999900001"}'::jsonb),
    ('{"planet_id":""}'::jsonb),
    ('{"fleet_id":"9-999900001"}'::jsonb),
    ('{"defender_struct_id":"5-999900001","protected_struct_id":"5-999900002"}'::jsonb),
    ('{"attackerPlayerId":"1-999900001","eventAttackShotDetail":[{"targetPlayerId":"1-999900001"},{"targetPlayerId":"1-999900002"},{"targetPlayerId":"1-999900002"},{"targetPlayerId":""},{}]}'::jsonb),
    ('{"attackerPlayerId":"","eventAttackShotDetail":{}}'::jsonb)
) details(detail);

INSERT INTO structs.planet_activity(time, planet_id, seq, category, detail, block_height)
SELECT time, planet_id, seq, category, detail, block_height FROM activity_expected;

DO $$
BEGIN
    IF EXISTS (
        (SELECT a.time, a.planet_id, a.seq, r.player_id, r.role, a.category, a.block_height
           FROM activity_expected a
           CROSS JOIN LATERAL structs.planet_activity_players(a.category, a.planet_id, a.detail) r
         EXCEPT ALL
         SELECT time, planet_id, seq, player_id, role, category, block_height
           FROM structs.planet_activity_player WHERE planet_id='2-999900001')
        UNION ALL
        (SELECT time, planet_id, seq, player_id, role, category, block_height
           FROM structs.planet_activity_player WHERE planet_id='2-999900001'
         EXCEPT ALL
         SELECT a.time, a.planet_id, a.seq, r.player_id, r.role, a.category, a.block_height
           FROM activity_expected a
           CROSS JOIN LATERAL structs.planet_activity_players(a.category, a.planet_id, a.detail) r)
    ) THEN
        RAISE EXCEPTION 'optimized attribution differs from resolver';
    END IF;
END $$;

UPDATE structs.player_object SET player_id='1-999900004' WHERE object_id='5-999900001';
INSERT INTO structs.planet_activity(time, planet_id, seq, category, detail, block_height)
VALUES ('2026-11-06 00:00:01+00', '2-999900001', 2100000000, 'struct_health',
        '{"struct_id":"5-999900001"}', 999900002);
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM structs.planet_activity_player
        WHERE planet_id='2-999900001' AND seq=2100000000
          AND player_id='1-999900004' AND role='owner'
    ) THEN
        RAISE EXCEPTION 'attribution failed to observe ownership change';
    END IF;
END $$;
ROLLBACK;
