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

    CREATE TABLE cache.attributes_tmp (
      composite_key VARCHAR NOT NULL, -- composed type.key
      value         VARCHAR NULL
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
                    body->>'id',
                    (body->>'allocationType')::INTEGER,

                    body->>'sourceObjectId',
                    (body->>'index')::INTEGER,
                    body->>'destinationId',

                    body->>'creator',
                    body->>'controller',
                    (body->>'locked')::BOOLEAN,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        destination_id = EXCLUDED.destination_id,
                        controller = EXCLUDED.controller,
                        locked = EXCLUDED.locked,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventGuild.guild' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.guild
                VALUES (
                    (body->>'id')::INTEGER,
                    (body->>'index')::INTEGER,

                    body->>'endpoint',
                    '',             -- public_key
                    '',             -- name
                    '',              -- tag
                    '',             -- logo
                    '{}'::JSONB,    -- socials
                    '',             -- website
                    false,          -- this_infrastructure
                    '',             -- status
                    (body->>'joinInfusionMinimum')::INTEGER,
                    (body->>'joinInfusionMinimumBypassByRequest')::INTEGER,
                    (body->>'joinInfusionMinimumBypassByInvite')::INTEGER,

                    body->>'primaryReactorId',
                    body->>'entrySubstationId',

                    body->>'creator',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        api = EXCLUDED.api,
                        this_infrastructure = EXCLUDED.this_infrastructure,
                        join_infusion_minimum = EXCLUDED.join_infusion_minimum,
                        join_infusion_minimum_by_request = EXCLUDED.join_infusion_minimum_by_request,
                        join_infusion_minimum_by_invite = EXCLUDED.join_infusion_minimum_by_invite,
                        primary_reactor_id = EXCLUDED.primary_reactor_id,
                        entry_substation_id = EXCLUDED.entry_substation_id,
                        updated_at = NOW();


        ELSIF NEW.composite_key = 'structs.EventInfusion.infusion' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.infusion
                VALUES (
                    (body->>'destinationType')::INTEGER,
                    body->>'destinationId',

                    body->>'playerId',
                    body->>'address',

                    (body->>'fuel')::INTEGER,
                    (body->>'power')::INTEGER,

                    (body->>'commission')::NUMERIC,

                    NOW(),
                    NOW()
                ) ON CONFLICT (destination_id, address) DO UPDATE
                    SET
                        fuel = EXCLUDED.fuel,
                        power = EXCLUDED.power,
                        commission = EXCLUDED.commission,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.EventPlanet.planet' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.planet
                VALUES (
                    body->>'id',
                    '', -- name
                    (body->>'maxOre')::INTEGER,
                    body->>'creator',
                    body->>'owner',
                    body,
                    body->>'status',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        owner = EXCLUDED.owner,
                        state = EXCLUDED.state,
                        status = EXCLUDED.status,
                        updated_at = NOW();




        ELSIF NEW.composite_key = 'structs.EventPlayer.player' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.player
                VALUES (
                    body->>'id',
                    (body->>'index')::INTEGER,
                    '', -- username
                    '', -- pfp
                    body->>'guildId',
                    body->>'substationId',
                    body->>'planetId',

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


        ELSIF NEW.composite_key = 'structs.EventReactor.reactor' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.reactor
                VALUES (
                    body->>'id',
                    body->>'validator',
                    body->>'guildId',
                    (body->>'default_commission')::NUMERIC,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        guild_id = EXCLUDED.guild_id,
                        default_commission = EXCLUDED.default_commission,
                        updated_at = NOW();


        ELSIF NEW.composite_key = 'structs.EventStruct.structure' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.struct
                VALUES (
                    body->>'id',
                    body->>'type',
                    body->>'owner',
                    (body)::JSONB,
                    body->>'creator',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        owner = EXCLUDED.owner,
                        state = EXCLUDED.state,
                        updated_at = NOW();



        ELSIF NEW.composite_key = 'structs.EventSubstation.substation' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.substation
                VALUES (
                    body->>'id',
                    body->>'owner',
                    body->>'creator',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        owner = EXCLUDED.owner,
                        updated_at = NOW();



        -- Make generic permission stuff happen
        ELSIF NEW.composite_key = 'structs.EventPermission.body' THEN


        -- make generic grid stuff happen
        ELSIF NEW.composite_key = 'structs.EventGrid.body' THEN
                    body := (NEW.value)::jsonb;

        UPDATE structs.grid
        SET
            -- ore_remaining = (body->>'value')::INTEGER
        WHERE planet.id = (body->>'key')::INTEGER;

        END IF;
        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.attributes
     FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

    CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.attributes_tmp
    FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();
    --CREATE TRIGGER ADD_QUEUE INSTEAD OF INSERT ON cache.attributes
    --    FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

    -- Used by the manual update script
    create table cache.tmp_json (data jsonb);

COMMIT;

