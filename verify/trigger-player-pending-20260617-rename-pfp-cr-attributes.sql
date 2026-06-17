-- Verify structs-pg:trigger-player-pending-20260617-rename-pfp-cr-attributes on pg

BEGIN;

    SELECT 'structs.player_pending_join_proxy()'::regprocedure;

    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('structs.player_pending_join_proxy()'::regprocedure)
        INTO body;
        IF body NOT LIKE '%pfp_client_render_attributes%' THEN
            RAISE EXCEPTION 'PLAYER_PENDING_JOIN_PROXY does not reference pfp_client_render_attributes';
        END IF;
        IF body NOT LIKE '%player-pfp-cr-attributes%' THEN
            RAISE EXCEPTION 'PLAYER_PENDING_JOIN_PROXY does not thread player-pfp-cr-attributes';
        END IF;
    END
    $$;

ROLLBACK;
