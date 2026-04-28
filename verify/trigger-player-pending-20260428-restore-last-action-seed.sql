-- Verify structs-pg:trigger-player-pending-20260428-restore-last-action-seed on pg

BEGIN;

    SELECT 'structs.player_pending_merge()'::regprocedure;

    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('structs.player_pending_merge()'::regprocedure)
        INTO body;

        IF body NOT LIKE '%''lastAction''%' THEN
            RAISE EXCEPTION 'structs.PLAYER_PENDING_MERGE no longer seeds the lastAction grid row';
        END IF;
    END
    $$;

    DO $$
    DECLARE
        missing INT;
    BEGIN
        SELECT count(*) INTO missing
        FROM   structs.player p
        WHERE  NOT EXISTS (
            SELECT 1
            FROM   structs.grid g
            WHERE  g.object_id      = p.id
              AND  g.attribute_type = 'lastAction'
        );

        IF missing > 0 THEN
            RAISE EXCEPTION '% player(s) still missing a lastAction grid seed row', missing;
        END IF;
    END
    $$;

ROLLBACK;
