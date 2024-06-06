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
    CREATE UNLOGGED TABLE cache.blocks (
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
    CREATE INDEX idx_blocks_height ON cache.blocks(height);
    CREATE INDEX idx_blocks_rowid ON cache.blocks(rowid);

    -- The tx_results table records metadata about transaction results.  Note that
    -- the events from a transaction are stored separately.
    CREATE UNLOGGED TABLE cache.tx_results (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block to which this transaction belongs.
      block_id BIGINT NOT NULL REFERENCES cache.blocks(rowid) ON DELETE CASCADE,
      -- The sequential index of the transaction within the block.
      index INTEGER NOT NULL,
      -- When this result record was logged into the sink, in UTC.
      created_at TIMESTAMPTZ NOT NULL,
      -- The hex-encoded hash of the transaction.
      tx_hash VARCHAR NOT NULL,
      -- The protobuf wire encoding of the TxResult message.
      tx_result BYTEA NOT NULL,

      UNIQUE (block_id, index)
    ) ;

    --CREATE OR REPLACE VIEW cache.tx_results AS SELECT * FROM cache.tx_results_tbl;
    --CREATE OR REPLACE RULE block_tx_results AS ON INSERT to cache.tx_results DO INSTEAD NOTHING;


    -- The events table records events. All events (both block and transaction) are
    -- associated with a block ID; transaction events also have a transaction ID.
    CREATE UNLOGGED TABLE cache.events (
      rowid BIGSERIAL PRIMARY KEY,

      -- The block and transaction this event belongs to.
      -- If tx_id is NULL, this is a block event.
      block_id BIGINT NOT NULL REFERENCES cache.blocks(rowid) ON DELETE CASCADE,
      tx_id    BIGINT NULL,

      -- The application-defined type label for the event.
      type VARCHAR NOT NULL
    );

    -- The attributes table records event attributes.
    CREATE UNLOGGED TABLE cache.attributes (
       event_id      BIGINT NOT NULL REFERENCES cache.events(rowid) ON DELETE CASCADE,
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
        IF NEW.composite_key = 'structs.structs.EventAllocation.allocation' THEN
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

        ELSIF NEW.composite_key = 'structs.structs.EventGuild.guild' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.guild
                VALUES (
                    body->>'id',
                    (body->>'index')::INTEGER,

                    body->>'endpoint',

                    (body->>'joinInfusionMinimum')::INTEGER,
                    body->>'joinInfusionMinimumBypassByRequest',
                    body->>'joinInfusionMinimumBypassByInvite',

                    body->>'primaryReactorId',
                    body->>'entrySubstationId',

                    body->>'creator',
                    body->>'owner',
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        endpoint = EXCLUDED.endpoint,
                        join_infusion_minimum = EXCLUDED.join_infusion_minimum,
                        join_infusion_minimum_bypass_by_request = EXCLUDED.join_infusion_minimum_bypass_by_request,
                        join_infusion_minimum_bypass_by_invite = EXCLUDED.join_infusion_minimum_bypass_by_invite,
                        primary_reactor_id = EXCLUDED.primary_reactor_id,
                        entry_substation_id = EXCLUDED.entry_substation_id,
                        owner = EXCLUDED.owner,
                        updated_at = NOW();


        ELSIF NEW.composite_key = 'structs.structs.EventInfusion.infusion' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.infusion
                VALUES (
                    body->>'destinationId',
                    body->>'address',

                    body->>'destinationType',
                    body->>'playerId',

                    (body->>'fuel')::INTEGER,
                    (body->>'defusing')::INTEGER,
                    (body->>'power')::INTEGER,
                    (body->>'ratio')::INTEGER,

                    (body->>'commission')::NUMERIC,

                    NOW(),
                    NOW()
                ) ON CONFLICT (destination_id, address) DO UPDATE
                    SET
                        fuel = EXCLUDED.fuel,
                        defusing = EXCLUDED.defusing,
                        power = EXCLUDED.power,
                        ratio = EXCLUDED.ratio,
                        commission = EXCLUDED.commission,
                        updated_at = NOW();

        ELSIF NEW.composite_key = 'structs.structs.EventPlanet.planet' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.planet
                VALUES (
                    body->>'id',
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


        ELSIF NEW.composite_key = 'structs.structs.EventPlayer.player' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.player
                VALUES (
                    body->>'id',
                    (body->>'index')::INTEGER,
                    body->>'primaryAddress',
                    body->>'guildId',
                    body->>'substationId',
                    body->>'planetId',

                    (body->>'storage')::JSONB,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE
                    SET
                        primary_address = EXCLUDED.primary_address,
                        guild_id = EXCLUDED.guild_id,
                        substation_id = EXCLUDED.substation_id,
                        planet_id = EXCLUDED.planet_id,
                        storage = EXCLUDED.storage,
                        updated_at = NOW();


        ELSIF NEW.composite_key = 'structs.structs.EventReactor.reactor' THEN
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


        ELSIF NEW.composite_key = 'structs.structs.EventStruct.structure' THEN
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



        ELSIF NEW.composite_key = 'structs.structs.EventSubstation.substation' THEN
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

            ELSIF NEW.composite_key = 'structs.structs.EventGuildMembershipApplication.guildMembershipApplication' THEN
                        body := (NEW.value)::jsonb;

            INSERT INTO structs.guild_membership_application
            VALUES (
                        body->>'guildId',
                        body->>'playerId',
                        body->>'joinType',
                        body->>'registrationStatus',
                        body->>'proposer',
                        body->>'substationId',
                        NOW(),
                        NOW()
                   ) ON CONFLICT (guild_id, player_id) DO UPDATE
            SET
                join_type = EXCLUDED.join_type,
                status = EXCLUDED.status,
                proposer = EXCLUDED.proposer,
                substation_id = EXCLUDED.substation_id,
                updated_at = NOW();

        -- Make generic address association stuff happen
        ELSIF NEW.composite_key = 'structs.structs.EventAddressActivity.addressActivity' THEN
                            body := (NEW.value)::jsonb;

        INSERT INTO structs.player_address_activity
        VALUES (
                       body->>'address',
                       (body->>'blockHeight')::INTEGER,
                       (body->>'blockTime')::TIMESTAMPTZ
               ) ON CONFLICT (address) DO UPDATE
        SET
            block_height = EXCLUDED.block_height,
            block_time = EXCLUDED.block_time;

        -- Make generic address association stuff happen
        ELSIF NEW.composite_key = 'structs.structs.EventAddressAssociation.addressAssociation' THEN
                    body := (NEW.value)::jsonb;

        INSERT INTO structs.player_address
        VALUES (
                       body->>'address',
                       '1-' || (body->>'playerIndex')::CHARACTER VARYING, -- cast the index into the proper player account ID
                       body->>'registrationStatus',
                       NOW(),
                       NOW()
               ) ON CONFLICT (address) DO UPDATE
        SET
            status = EXCLUDED.status,
            player_id = EXCLUDED.player_id,
            updated_at = EXCLUDED.updated_at;

        -- Make generic permission stuff happen
        ELSIF NEW.composite_key = 'structs.structs.EventPermission.permissionRecord' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.permission
            VALUES (
                body->>'permissionId',
                (body->>'value')::INTEGER,
                NOW()
            ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at;

        -- make generic grid stuff happen
        ELSIF NEW.composite_key = 'structs.structs.EventGrid.gridRecord' THEN
            body := (NEW.value)::jsonb;

            INSERT INTO structs.grid
            VALUES (
                body->>'attributeId',
                (body->>'value')::INTEGER,
                NOW()
            ) ON CONFLICT (id) DO UPDATE
            SET
                val = EXCLUDED.val,
                updated_at = EXCLUDED.updated_at;

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


    -- Pruning try
    CREATE OR REPLACE PROCEDURE cache.CLEAN_QUEUE()
    AS
    $BODY$
    BEGIN

        -- The 2,000 number here was pulled roughly out of an ass
        -- Previous attempt was 1,000 and it appeared to result in orphaned attributes
        DELETE FROM cache.blocks where rowid in (select rowid FROM cache.blocks order by height desc offset 2000 FOR UPDATE SKIP LOCKED);

    END
    $BODY$
    LANGUAGE plpgsql SECURITY DEFINER;

    CREATE EXTENSION pg_cron;

    SELECT cron.schedule('clean', '1 * * * *', 'CALL cache.CLEAN_QUEUE()');

COMMIT;

