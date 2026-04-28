-- Verify structs-pg:table-player-meta-20260427-collapse-pk on pg

BEGIN;

    DO $$
    DECLARE
        pk_cols text;
    BEGIN
        SELECT string_agg(a.attname, ',' ORDER BY array_position(c.conkey, a.attnum))
        INTO pk_cols
        FROM pg_constraint c
        JOIN pg_class      t ON t.oid = c.conrelid
        JOIN pg_namespace  n ON n.oid = t.relnamespace
        JOIN pg_attribute  a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
        WHERE n.nspname = 'structs'
          AND t.relname = 'player_meta'
          AND c.contype = 'p';

        IF pk_cols IS DISTINCT FROM 'id' THEN
            RAISE EXCEPTION 'expected structs.player_meta PK to be (id), got (%)', pk_cols;
        END IF;
    END
    $$;

ROLLBACK;
