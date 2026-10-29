-- Deploy structs-pg:table-economy-20261029-v022-foundation to pg
-- Additive storage only. This does not activate v0.22 or change ledger identity.

BEGIN;

CREATE TABLE structs.vault (
    owner_id VARCHAR PRIMARY KEY CHECK (owner_id ~ '^[01]-[1-9][0-9]*$'),
    address VARCHAR NOT NULL UNIQUE CHECK (address <> ''),
    account_number NUMERIC NOT NULL CHECK (account_number >= 0 AND account_number <= 18446744073709551615 AND account_number = trunc(account_number)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Do not put a vault in player_address: that table also authorizes login.
-- Owner rows can be emitted later in the same block, so there is no immediate
-- player-only foreign key. The view resolves only existing canonical owners.
CREATE VIEW structs.asset_owner AS
    SELECT v.address, 'player'::structs.object_type AS owner_type,
           p.id AS owner_id, p.guild_id, TRUE AS is_vault
      FROM structs.vault v JOIN structs.player p ON p.id = v.owner_id
    UNION ALL
    SELECT v.address, 'guild'::structs.object_type, g.id, g.id, TRUE
      FROM structs.vault v JOIN structs.guild g ON g.id = v.owner_id
    UNION ALL
    SELECT pa.address, 'player'::structs.object_type, p.id, p.guild_id, FALSE
      FROM structs.player_address pa JOIN structs.player p ON p.id = pa.player_id
     WHERE pa.status = 'approved'
       AND NOT EXISTS (SELECT 1 FROM structs.vault v WHERE v.address = pa.address);

COMMENT ON VIEW structs.asset_owner IS
    'Current economic ownership, not signing authority. Guild vaults remain guild assets; player membership is resolved live.';

ALTER TABLE structs.infusion
    ADD COLUMN owner_id VARCHAR,
    ADD COLUMN generator_disabled BOOLEAN NOT NULL DEFAULT FALSE;
-- NULL/empty owner_id deliberately falls back to player_id while old writers
-- still run. Copying player_id now would freeze later legacy reassignments.
CREATE INDEX infusion_owner_destination_address_idx ON structs.infusion
    ((COALESCE(NULLIF(owner_id, ''), player_id)), destination_id, address);

ALTER TABLE structs.substation
    ADD COLUMN deletion_pending BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN deletion_migration_substation_id VARCHAR NOT NULL DEFAULT '';

ALTER TABLE structs.guild
    ADD COLUMN rank_purchase_base_price NUMERIC NOT NULL DEFAULT 0
        CHECK (rank_purchase_base_price >= 0 AND rank_purchase_base_price <= 18446744073709551615 AND rank_purchase_base_price = trunc(rank_purchase_base_price)),
    ADD COLUMN rank_purchase_step_increase NUMERIC NOT NULL DEFAULT 0
        CHECK (rank_purchase_step_increase >= 0 AND rank_purchase_step_increase <= 18446744073709551615 AND rank_purchase_step_increase = trunc(rank_purchase_step_increase)),
    ADD COLUMN rank_purchase_minimum_rank NUMERIC NOT NULL DEFAULT 0
        CHECK (rank_purchase_minimum_rank >= 0 AND rank_purchase_minimum_rank <= 18446744073709551615 AND rank_purchase_minimum_rank = trunc(rank_purchase_minimum_rank)),
    ADD COLUMN join_by_rank_purchase_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN bank_convert_in_fee NUMERIC CHECK (bank_convert_in_fee >= 0 AND bank_convert_in_fee < 1),
    ADD COLUMN bank_convert_out_fee NUMERIC CHECK (bank_convert_out_fee >= 0 AND bank_convert_out_fee < 1),
    ADD COLUMN charter_solver_id VARCHAR;

CREATE TABLE structs.owner_reactor_diversity (
    owner_id VARCHAR PRIMARY KEY CHECK (owner_id ~ '^[01]-[1-9][0-9]*$'),
    power NUMERIC NOT NULL CHECK (power >= 0 AND power < 'Infinity'::numeric AND power = trunc(power)),
    squared_power NUMERIC NOT NULL CHECK (squared_power >= 0 AND squared_power < 'Infinity'::numeric AND squared_power = trunc(squared_power)),
    applied_bonus NUMERIC NOT NULL CHECK (applied_bonus >= 0 AND applied_bonus <= 18446744073709551615 AND applied_bonus = trunc(applied_bonus)),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE structs.reactor_commission_revision (
    reactor_id VARCHAR PRIMARY KEY CHECK (reactor_id ~ '^3-[1-9][0-9]*$'),
    slash_revision NUMERIC NOT NULL CHECK (slash_revision >= 0 AND slash_revision <= 18446744073709551615 AND slash_revision = trunc(slash_revision)),
    reconciled_slash_revision NUMERIC NOT NULL CHECK (reconciled_slash_revision >= 0 AND reconciled_slash_revision <= 18446744073709551615 AND reconciled_slash_revision = trunc(reconciled_slash_revision)),
    CHECK (reconciled_slash_revision <= slash_revision),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE structs.reactor_stake_cap (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    active BOOLEAN NOT NULL,
    cap_bps NUMERIC NOT NULL CHECK (cap_bps >= 0 AND cap_bps <= 18446744073709551615 AND cap_bps = trunc(cap_bps)),
    min_validators NUMERIC NOT NULL CHECK (min_validators >= 0 AND min_validators <= 18446744073709551615 AND min_validators = trunc(min_validators)),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- An empty table means no authoritative snapshot; do not seed activation.

GRANT USAGE ON SCHEMA structs TO structs_indexer;

GRANT SELECT, INSERT, UPDATE, DELETE ON
    structs.vault, structs.owner_reactor_diversity,
    structs.reactor_commission_revision, structs.reactor_stake_cap
    TO structs_indexer;
GRANT SELECT ON structs.asset_owner TO structs_indexer;
GRANT SELECT ON structs.vault, structs.asset_owner,
    structs.owner_reactor_diversity, structs.reactor_commission_revision,
    structs.reactor_stake_cap TO structs_webapp;

COMMIT;
