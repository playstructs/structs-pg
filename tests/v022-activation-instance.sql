-- Disposable Sqitch database only; fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE structs_webapp;
DO $$
DECLARE first_id UUID; second_id UUID;
BEGIN
    INSERT INTO structs.player_address_activation_code(player_id,code,logged_in_address)
        VALUES('1-990982','activation-instance-test','activation-approver') RETURNING activation_id INTO first_id;
    INSERT INTO structs.player_address_pending(code,address,signature,pubkey,activation_id)
        VALUES('activation-instance-test','activation-target','signature','pubkey',first_id);
    BEGIN
        INSERT INTO structs.player_address_pending(code,address,signature,pubkey,activation_id)
            VALUES('activation-instance-test','another-target','signature','pubkey',first_id);
        RAISE EXCEPTION 'one code instance accepted two devices';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO structs.player_address_pending(code,address,signature,pubkey,activation_id)
            VALUES('activation-instance-missing','another-target','signature','pubkey',gen_random_uuid());
        RAISE EXCEPTION 'missing code instance accepted a device';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    -- Old clients remain insert-compatible, but their unbound rows have no new authority.
    INSERT INTO structs.player_address_pending(code,address,signature,pubkey)
        VALUES('activation-instance-test','legacy-target','signature','pubkey');
    DELETE FROM structs.player_address_activation_code WHERE activation_id=first_id;
    IF EXISTS(SELECT FROM structs.player_address_pending WHERE activation_id=first_id) THEN
        RAISE EXCEPTION 'deleted code retained its bound consent';
    END IF;
    IF NOT EXISTS(SELECT FROM structs.player_address_pending WHERE address='legacy-target' AND activation_id IS NULL) THEN
        RAISE EXCEPTION 'legacy row was unexpectedly removed';
    END IF;
    INSERT INTO structs.player_address_activation_code(player_id,code,logged_in_address)
        VALUES('1-990982','activation-instance-test','activation-approver') RETURNING activation_id INTO second_id;
    IF second_id=first_id THEN RAISE EXCEPTION 'short code reuse retained an issued identity'; END IF;
    BEGIN
        INSERT INTO structs.player_address_pending(code,address,signature,pubkey,activation_id)
            VALUES('activation-instance-test','activation-target','signature','pubkey',first_id);
        RAISE EXCEPTION 'reused short code accepted obsolete instance';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
END $$;
RESET ROLE;
UPDATE structs.player_address_activation_code SET created_at=now()-interval '61 minutes' WHERE code='activation-instance-test';
INSERT INTO structs.player_address_pending(code,address,signature,pubkey,activation_id)
    SELECT code,'expiry-target','signature','pubkey',activation_id FROM structs.player_address_activation_code WHERE code='activation-instance-test';
CALL structs.clean_activation_code();
DO $$ BEGIN
    IF EXISTS(SELECT FROM structs.player_address_pending WHERE address='expiry-target') THEN
        RAISE EXCEPTION 'expiry cleanup retained pending device';
    END IF;
END $$;
ROLLBACK;
