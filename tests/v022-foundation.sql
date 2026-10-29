-- Run only on a disposable database deployed through the real Sqitch chain.
-- Fixtures roll back, including the ordinary onboarding/notification triggers.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO structs.guild (id) VALUES ('0-900001'), ('0-900002');
INSERT INTO structs.player (id, primary_address, guild_id)
VALUES ('1-900001', 'v022-primary', '0-900001');
INSERT INTO structs.player_address (address, player_id, guild_id, status)
VALUES ('v022-revoked', '1-900001', '0-900001', 'revoked'),
       ('v022-pending', '1-900001', '0-900001', 'pending');
INSERT INTO structs.vault (owner_id, address, account_number)
VALUES ('1-900001', 'v022-player-vault', 18446744073709551615),
       ('0-900001', 'v022-guild-vault', 0);
DO $$
DECLARE bad NUMERIC;
BEGIN
    IF (SELECT count(*) FROM structs.asset_owner WHERE owner_id = '1-900001') <> 2 THEN
        RAISE EXCEPTION 'player must own primary and vault only';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM structs.asset_owner WHERE address = 'v022-guild-vault'
        AND owner_type = 'guild' AND owner_id = '0-900001') THEN
        RAISE EXCEPTION 'guild treasury must remain guild owned';
    END IF;
    IF EXISTS (SELECT 1 FROM structs.player_address WHERE address LIKE 'v022-%-vault') THEN
        RAISE EXCEPTION 'vault became a signing address';
    END IF;
    UPDATE structs.player SET guild_id = '0-900002' WHERE id = '1-900001';
    IF EXISTS (SELECT 1 FROM structs.asset_owner WHERE owner_id = '1-900001' AND guild_id <> '0-900002') THEN
        RAISE EXCEPTION 'owner membership is stale';
    END IF;
    BEGIN
        INSERT INTO structs.vault VALUES ('1-900002', 'v022-player-vault', 1, NOW(), NOW());
        RAISE EXCEPTION 'duplicate vault address accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    FOREACH bad IN ARRAY ARRAY[-1::numeric, 1.5::numeric, 18446744073709551616::numeric,
        'NaN'::numeric, 'Infinity'::numeric] LOOP
        BEGIN
            INSERT INTO structs.vault (owner_id,address,account_number) VALUES ('1-900003','v022-invalid',bad);
            RAISE EXCEPTION 'invalid unsigned value accepted: %', bad;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    BEGIN
        INSERT INTO structs.reactor_commission_revision VALUES ('3-900001',0,1,NOW());
        RAISE EXCEPTION 'certified revision ahead of issued revision accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    INSERT INTO structs.reactor_stake_cap (active,cap_bps,min_validators) VALUES (FALSE,3000,10);
    BEGIN
        INSERT INTO structs.reactor_stake_cap (active,cap_bps,min_validators) VALUES (TRUE,3000,10);
        RAISE EXCEPTION 'duplicate stake cap accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    INSERT INTO structs.owner_reactor_diversity (owner_id,power,squared_power,applied_bonus)
    VALUES ('1-900001',18446744073709551616,340282366920938463463374607431768211456,0);
    UPDATE structs.owner_reactor_diversity SET power=0,squared_power=0,applied_bonus=0;
    IF EXISTS (SELECT 1 FROM structs.owner_reactor_diversity WHERE power <> 0) THEN
        RAISE EXCEPTION 'explicit zero failed';
    END IF;
    -- An old writer may change player_id after additive deployment.
    INSERT INTO structs.infusion (destination_id,address,player_id)
    VALUES ('3-900001','v022-primary','1-900001');
    UPDATE structs.infusion SET player_id='1-900002' WHERE destination_id='3-900001' AND address='v022-primary';
    IF (SELECT COALESCE(NULLIF(owner_id,''),player_id) FROM structs.infusion
        WHERE destination_id='3-900001' AND address='v022-primary') <> '1-900002' THEN
        RAISE EXCEPTION 'additive owner default froze legacy ownership';
    END IF;
END $$;
-- The isolated test roles must be NOSUPERUSER; otherwise these assertions
-- would not exercise the release grants.
SET LOCAL ROLE structs_webapp;
SELECT owner_id FROM structs.asset_owner WHERE address='v022-player-vault';
DO $$
BEGIN
    BEGIN
        INSERT INTO structs.vault (owner_id,address,account_number) VALUES ('1-900004','v022-forbidden',0);
        RAISE EXCEPTION 'webapp can write indexer-owned vaults';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;
RESET ROLE;
SET LOCAL ROLE structs_indexer;
INSERT INTO structs.vault (owner_id,address,account_number) VALUES ('1-900004','v022-indexer',0);
DELETE FROM structs.vault WHERE owner_id='1-900004';
ROLLBACK;
