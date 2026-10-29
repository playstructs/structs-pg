-- Verify structs-pg:view-guild-bank-20261029-current-supply on pg
BEGIN;
SELECT id, denom, minted_supply, collateral_balance, ratio FROM view.guild_bank WHERE FALSE;
DO $$
BEGIN
    IF position('api_guild_bank' IN pg_get_viewdef('view.guild_bank'::regclass)) = 0 THEN
        RAISE EXCEPTION 'guild bank view must use the maintained bank projection';
    END IF;
END $$;
ROLLBACK;
