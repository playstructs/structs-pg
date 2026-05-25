-- Verify structs-pg:view-guild-20260525-add-chain-ugc on pg

BEGIN;

    SELECT onchain_name, pfp, name FROM view.guild WHERE FALSE;
    SELECT onchain_name, pfp, name FROM view.leaderboard_guild WHERE FALSE;

ROLLBACK;
