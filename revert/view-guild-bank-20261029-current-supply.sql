-- Revert structs-pg:view-guild-bank-20261029-current-supply from pg
BEGIN;
    CREATE OR REPLACE VIEW view.guild_bank AS
        WITH list AS (SELECT address_tag.address FROM structs.address_tag WHERE address_tag.label = 'Type' and address_tag.entry = 'Bank Collateral Pool'),
            base AS (
                SELECT
                    address_tag.entry as id,
                    'uguild.' || address_tag.entry as denom,
                    (SELECT SUM(case when ledger.direction = 'debit' then ledger.amount_p * -1 ELSE ledger.amount_p END) as balance
                     FROM structs.ledger
                     WHERE action IN ('minted', 'burned') AND ledger.denom = 'uguild.' || address_tag.entry
                    ) as minted_supply,
                    (SELECT SUM(case when ledger.direction='debit' then ledger.amount_p*-1 ELSE ledger.amount_p END) as balance
                     FROM structs.ledger where ledger.address = list.address
                    ) as collateral_balance
                FROM list
                         LEFT JOIN structs.address_tag on address_tag.address = list.address AND address_tag.label = 'GuildId'
            ) SELECT base.*, base.collateral_balance / base.minted_supply as ratio FROM base;

COMMENT ON COLUMN structs.api_guild_bank.supply IS 'Chain precision in the unit of denom (uguild.* micrograms).';
COMMIT;
