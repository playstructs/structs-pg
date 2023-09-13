-- Deploy structs-pg:cache-system to pg

BEGIN;

    /*
      This file defines the database schema for the PostgresQL ("psql") event sink
      implementation in Tendermint. The operator must create a database and install
      this schema before using the database to index events.
     */

    CREATE SCHEMA cache;

    -- The blocks table records metadata about each block.
    -- The block record does not include its events or transactions (see tx_results).
    CREATE TABLE cache.blocks (
      rowid      BIGSERIAL PRIMARY KEY,

      height     BIGINT NOT NULL,
      chain_id   VARCHAR NOT NULL,

      -- When this block header was logged into the sink, in UTC.
      created_at TIMESTAMPTZ NOT NULL,

      UNIQUE (height, chain_id)
    );

    -- Index blocks by height and chain, since we need to resolve block IDs when
    -- indexing transaction records and transaction events.
    CREATE INDEX idx_blocks_height_chain ON cache.blocks(height, chain_id);

    -- The tx_results table records metadata about transaction results.  Note that
    -- the events from a transaction are stored separately.
    CREATE TABLE cache.tx_results (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block to which this transaction belongs.
      block_id BIGINT NOT NULL,
      -- The sequential index of the transaction within the block.
      index INTEGER NOT NULL,
      -- When this result record was logged into the sink, in UTC.
      created_at TIMESTAMPTZ NOT NULL,
      -- The hex-encoded hash of the transaction.
      tx_hash VARCHAR NOT NULL,
      -- The protobuf wire encoding of the TxResult message.
      tx_result BYTEA NOT NULL,

      UNIQUE (block_id, index)
    );

    --CREATE OR REPLACE VIEW cache.tx_results AS SELECT * FROM cache.tx_results_tbl;
    --CREATE OR REPLACE RULE block_tx_results AS ON INSERT to cache.tx_results DO INSTEAD NOTHING;


    -- The events table records events. All events (both block and transaction) are
    -- associated with a block ID; transaction events also have a transaction ID.
    CREATE TABLE cache.events (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block and transaction this event belongs to.
      -- If tx_id is NULL, this is a block event.
      block_id BIGINT NOT NULL,
      tx_id    BIGINT NULL,

      -- The application-defined type label for the event.
      type VARCHAR NOT NULL
    );

    -- The attributes table records event attributes.
    CREATE TABLE cache.attributes (
       event_id      BIGINT NOT NULL,
       key           VARCHAR NOT NULL, -- bare key
       composite_key VARCHAR NOT NULL, -- composed type.key
       value         VARCHAR NULL,
       UNIQUE (event_id, key)
    );

    --CREATE OR REPLACE VIEW cache.attributes AS SELECT * FROM cache.attributes_tbl;

    CREATE TABLE cache.queue (
        channel CHARACTER VARYING,
        id CHARACTER VARYING,
        CONSTRAINT queue_unique UNIQUE (channel, id)
    );

    CREATE OR REPLACE FUNCTION cache.ADD_QUEUE()
      RETURNS trigger AS
    $BODY$
    DECLARE
        body jsonb;
    BEGIN
        IF NEW.composite_key = 'structs.EventAllocation.allocation' THEN

            body := (NEW.value)::jsonb;

            INSERT INTO structs.allocation
                VALUES (
                    (body->>'id')::INTEGER,
                    (body->>'power')::INTEGER,
                    body->>'sourceType',
                    (body->>'sourceReactorId')::INTEGER,
                    (body->>'sourceStructId')::INTEGER,
                    (body->>'sourceSubstationId')::INTEGER,
                    (body->>'destinationId')::INTEGER,
                    body->>'creator',
                    (body->>'controller')::INTEGER,
                    (body->>'locked')::BOOLEAN,
                    (body->>'hasLinkedInfusion')::BOOLEAN,
                    (body->>'linkedInfusion')::INTEGER,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        power = EXCLUDED.power,
                        destination_id = EXCLUDED.destination_id,
                        controller = EXCLUDED.controller,
                        locked = EXCLUDED.locked,
                        has_linked_infusion = EXCLUDED.has_linked_infusion,
                        linked_infusion = EXCLUDED.linked_infusion,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventGuild.guild' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.guild
                VALUES (
                    (body->>'id')::INTEGER,
                    body->>'endpoint',
                    '',     -- public_key
                    '',     -- name
                    '',     -- logo
                    '',     -- socials
                    '',     -- website
                    false,  -- this_infrastructure
                    '',     -- status
                    (body->>'guildJoinType')::INTEGER,
                    (body->>'infusionJoinMinimum')::INTEGER,
                    (body->>'primaryReactorId')::INTEGER,
                    (body->>'entrySubstationId')::INTEGER,
                    body->>'creator',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        api = EXCLUDED.api,
                        this_infrastructure = EXCLUDED.this_infastructure,
                        guild_join_type = EXCLUDED.guild_join_type,
                        infusion_join_minimum = EXCLUDED.infusion_join_minimum,
                        primary_reactor_id = EXCLUDED.primary_reactor_id,
                        entry_substation_id = EXCLUDED.entry_substation_id,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventInfusion.infusion' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.infusion
                VALUES (
                    body->>'destinationType',
                    (body->>'destinationReactorId')::INTEGER,
                    (body->>'destinationStructId')::INTEGER,
                    body->>'address',

                    (body->>'fuel')::INTEGER,
                    (body->>'energy')::INTEGER,

                    (body->>'linkedSourceAllocationId')::INTEGER,
                    (body->>'linkedPlayerAllocationId')::INTEGER,
                    NOW(),
                    NOW()
                ) ON CONFLICT (destination_type, destination_reactor_id, destination_struct_id, address) DO UPDATE
                    SET
                        fuel = EXCLUDED.fuel,
                        energy = EXCLUDED.energy,
                        linked_source_allocation_id = EXCLUDED.linked_source_allocation_id,
                        linked_player_allocation_id = EXCLUDED.linked_player_allocation_id,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventPlanet.planet' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.planet
                VALUES (
                    (body->>'id')::INTEGER,
                    '', -- name
                    (body->>'maxOre')::INTEGER,
                    (body->>'oreRemaining')::INTEGER,
                    (body->>'oreStored')::INTEGER,
                    body->>'creator',
                    (body->>'owner')::INTEGER,
                    (body->>'space')::INTEGER[],
                    (body->>'sky')::INTEGER[],
                    (body->>'land')::INTEGER[],
                    (body->>'water')::INTEGER[],
                    (body->>'space_slots')::INTEGER,
                    (body->>'sky_slots')::INTEGER,
                    (body->>'land_slots')::INTEGER,
                    (body->>'water_slots')::INTEGER,
                    body->>'status',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        owner = EXCLUDED.owner,
                        space = EXCLUDED.space,
                        sky = EXCLUDED.sky,
                        land = EXCLUDED.land,
                        water = EXCLUDED.water,
                        status = EXCLUDED.status,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventPlanetRefinementCount.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.planet
                SET
                    ore_remaining = (body->>'value')::INTEGER
                WHERE planet.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventPlanetOreCount.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.planet
                SET
                    ore_stored = (body->>'value')::INTEGER
                WHERE planet.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventPlayer.player' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.player
                VALUES (
                    (body->>'id')::INTEGER,
                    '', -- username
                    '', -- pfp
                    (body->>'guildId')::INTEGER,
                    (body->>'substationId')::INTEGER,
                    (body->>'planetId')::INTEGER,
                    (body->>'load')::INTEGER,
                    (body->>'storage')::JSONB,
                    body->>'status',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        guild_id = EXCLUDED.guild_id,
                        substation_id = EXCLUDED.substation_id,
                        planet_id = EXCLUDED.planet_id,
                        storage = EXCLUDED.storage,
                        status = EXCLUDED.status,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventPlayerLoad.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.player
            SET
                load = (body->>'value')::INTEGER
            WHERE player.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventReactor.reactor' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.reactor
                VALUES (
                    (body->>'id')::INTEGER,
                    body->>'validator',
                    (body->>'fuel')::INTEGER,
                    (body->>'energy')::INTEGER,
                    (body->>'load')::INTEGER,
                    (body->>'guildId')::INTEGER,
                    (body->>'automatedAllocations')::BOOLEAN,
                    (body->>'allowManualAllocations')::BOOLEAN,
                    (body->>'allowExternalAllocations')::BOOLEAN,
                    (body->>'allowUncappedAllocations')::BOOLEAN,
                    (body->>'delegateMinimumBeforeAllowedAllocations')::NUMERIC,
                    (body->>'delegateTaxOnAllocation')::NUMERIC,
                    (body->>'serviceSubstationId')::INTEGER,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        guild_id = EXCLUDED.guild_id,
                        automated_allocations = EXCLUDED.automated_allocations,
                        allow_manual_allocations = EXCLUDED.allow_manual_allocations,
                        allow_external_allocations = EXCLUDED.allow_external_allocations,
                        allow_uncapped_allocations = EXCLUDED.allow_uncapped_allocations,
                        delegate_minimum_before_allowed_allocartions = EXCLUDED.delegate_minimum_before_allowed_allocartions,
                        delegate_tax_on_allocation = EXCLUDED.delegate_tax_on_allocation,
                        service_substation_id = EXCLUDED.service_substation_id,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventReactorEnergy.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.reactor
            SET
                energy = (body->>'value')::INTEGER
            WHERE reactor.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventReactorFuel.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.reactor
            SET
                fuel = (body->>'value')::INTEGER
            WHERE reactor.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventReactorLoad.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.reactor
            SET
                load = (body->>'value')::INTEGER
            WHERE reactor.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventStruct.struct' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.struct
                VALUES (
                    (body->>'id')::INTEGER,
                    body->>'type',
                    (body->>'owner')::INTEGER,
                    (body->>'energy')::INTEGER,
                    (body->>'fuel')::INTEGER,
                    (body->>'load')::INTEGER,
                    (body)::JSONB,
                    body->>'creator',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        state = EXCLUDED.state,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventStructEnergy.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.struct
            SET
                energy = (body->>'value')::INTEGER
            WHERE struct.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventStructFuel.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.struct
            SET
                fuel = (body->>'value')::INTEGER
            WHERE struct.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventStructLoad.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.struct
            SET
                load = (body->>'value')::INTEGER
            WHERE struct.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventSubstation.substation' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.substation
                VALUES (
                    (body->>'id')::INTEGER,
                    (body->>'playerConnectionAllocation')::INTEGER,
                    (body->>'owner')::INTEGER,
                    body->>'creator',
                    (body->>'load')::INTEGER,
                    (body->>'energy')::INTEGER,
                    (body->>'connectedPlayerCount')::INTEGER,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        player_connection_allocation = EXCLUDED.player_connection_allocation,
                        owner = EXCLUDED.owner,
                        updated_at = NOW();
        ELSIF NEW.composite_key = 'structs.EventSubstationEnergy.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.substation
            SET
                energy = (body->>'value')::INTEGER
            WHERE substation.id = (body->>'key')::INTEGER;

        ELSIF NEW.composite_key = 'structs.EventSubstationLoad.body' THEN
            body := (NEW.value)::jsonb;

            UPDATE structs.substation
            SET
                load = (body->>'value')::INTEGER
            WHERE substation.id = (body->>'key')::INTEGER;

        END IF;
        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.attributes
     FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

    --CREATE TRIGGER ADD_QUEUE INSTEAD OF INSERT ON cache.attributes
    --    FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();


COMMIT;

