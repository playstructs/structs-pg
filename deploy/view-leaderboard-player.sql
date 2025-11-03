-- Deploy structs-pg:view-leaderboard-player to pg

BEGIN;


    CREATE OR REPLACE VIEW view.leaderboard_player AS
    WITH base AS (select player_address.player_id,
                         sum(case
                                 when ledger.direction = 'debit' then ledger.amount_p * -1
                                 ELSE ledger.amount_p END) as hard_balance,
                         denom                             as denom
                  from structs.ledger,
                       structs.player_address
                  WHERE
                          player_address.address = ledger.address
                  group by player_id, ledger.denom
    ), expanded as (
        SELECT base.player_id,
               sum(CASE denom WHEN 'ualpha' THEN base.hard_balance ELSE 0 END) as hard_balance,
               sum(CASE denom WHEN 'ualpha' THEN base.hard_balance WHEN 'ualpha.infused' THEN base.hard_balance WHEN 'ualpha.defusing' THEN base.hard_balance WHEN 'ore' THEN 0 ELSE (SELECT guild_bank.ratio * base.hard_balance FROM view.guild_bank where guild_bank.denom = base.denom) END) as paper_balance
        FROM base GROUP BY base.player_id
    )
    select
        expanded.player_id,
        player_discord.discord_username,
        expanded.hard_balance as alpha_balance,
        structs.UNIT_DISPLAY_FORMAT(expanded.hard_balance, 'ualpha') as display_alpha_balance,
        expanded.paper_balance as alpha_value,
        structs.UNIT_DISPLAY_FORMAT(expanded.paper_balance, 'ualpha') as display_alpha_value
    from
        expanded left join structs.player_discord on player_discord.player_id = expanded.player_id;


COMMIT;
