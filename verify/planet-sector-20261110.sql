-- Verify structs-pg:planet-sector-20261110 on pg
BEGIN;
SELECT sector FROM structs.planet WHERE false;
SELECT sector FROM view.planet WHERE false;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid='structs.planet'::regclass AND conname='planet_sector_valid' AND convalidated)
    THEN RAISE EXCEPTION 'planet sector constraint missing'; END IF;
    IF EXISTS (SELECT 1 FROM structs.planet WHERE sector IS NULL OR sector NOT IN (0,127,999,44))
    THEN RAISE EXCEPTION 'invalid planet sector'; END IF;
END $$;
ROLLBACK;
