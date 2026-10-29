-- Deploy structs-pg:view-guild-bank-20261029-current-supply to pg
BEGIN;

-- Keep the existing names/shape. minted_supply now includes the one genesis
-- bank baseline plus subsequent issuance/burn, as in the maintained projection.
CREATE OR REPLACE VIEW view.guild_bank AS
    SELECT b.guild_id AS id, b.denom, b.supply AS minted_supply,
           b.collateral AS collateral_balance, b.ratio
      FROM structs.api_guild_bank b
     WHERE EXISTS (
         SELECT 1 FROM structs.address_tag typ
         JOIN structs.address_tag gid ON gid.address=typ.address
          AND gid.label='GuildId' AND gid.entry=b.guild_id
         WHERE typ.label='Type' AND typ.entry='Bank Collateral Pool'
     );

COMMENT ON COLUMN structs.api_guild_bank.supply IS
    'Exact bank denomination supply: genesis bank balances once, plus later minted credits minus burned debits. Includes protected escrow and module holdings independently of economic ownership.';

COMMIT;
