-- Verify structs-pg:trigger-grass-20261029-v022-ownership on pg
BEGIN;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='structs.infusion'::regclass
        AND tgname='infusion_notify' AND tgenabled='O' AND tgtype=29) THEN
        RAISE EXCEPTION 'infusion notifier must be enabled for insert/update/delete rows';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='structs.ledger'::regclass
        AND tgname='inventory_notify' AND tgenabled='O') THEN
        RAISE EXCEPTION 'inventory notifier must be enabled';
    END IF;
    IF position('structs.asset_owner' IN pg_get_functiondef('structs.inventory_notify()'::regprocedure)) = 0
       OR position('amount_p_exact' IN pg_get_functiondef('structs.inventory_notify()'::regprocedure)) = 0
       OR position('octet_length' IN pg_get_functiondef('structs.inventory_notify()'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'inventory notification lacks ownership/exact-value/byte-limit contract';
    END IF;
END $$;
ROLLBACK;
