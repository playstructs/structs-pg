-- Disposable Sqitch database only. Legacy inserts keep unknown evidence.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE structs_indexer;
INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990985','origin-sql-fixture',0);
DO $$
BEGIN
    IF (SELECT account_created IS NOT NULL FROM structs.vault WHERE owner_id='1-990985') THEN
        RAISE EXCEPTION 'legacy insertion invented account origin';
    END IF;
END $$;
UPDATE structs.vault SET account_created=false WHERE owner_id='1-990985';
SET LOCAL ROLE structs_webapp;
DO $$
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'requires non-superuser role';
    END IF;
    IF (SELECT account_created IS DISTINCT FROM FALSE FROM structs.vault WHERE owner_id='1-990985') THEN
        RAISE EXCEPTION 'webapp could not read adopted account evidence';
    END IF;
END $$;
SELECT * FROM view.player_inventory WHERE player_id='1-990985';
SELECT * FROM structs.fleet WHERE FALSE;
SELECT * FROM structs.grid WHERE FALSE;
SELECT * FROM structs.guild_meta WHERE FALSE;
SELECT * FROM structs.player_address WHERE FALSE;
ROLLBACK;
