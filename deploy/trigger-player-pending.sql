-- Deploy structs-pg:trigger-player-pending to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_MERGE()
      RETURNS trigger AS
    $BODY$
    DECLARE
        pending_data RECORD;
        numrows INT;
    BEGIN

        -- TEMPORARY grid insert for last actions.
        -- Remove after next testnet launch
        insert into structs.grid values('11-'|| NEW.id, 'lastAction', 'player', NEW.index, NEW.id, 0, now());

        DELETE FROM structs.player_pending WHERE player_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;

        get diagnostics numrows = row_count;
        IF numrows = 0 THEN
            DELETE FROM structs.player_internal_pending WHERE player_internal_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;
            get diagnostics numrows = row_count;

            IF numrows > 0 THEN
                UPDATE signer.role SET player_id = NEW.id, status='ready' WHERE id=pending_data.role_id;
            END IF;
        END IF;

        IF numrows > 0 THEN
            INSERT INTO structs.player_meta
            VALUES (NEW.id,
                pending_data.guild_id,
                pending_data.username,
                pending_data.pfp,
                '',
                NOW(),
                NOW()
               );

        END IF;

        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER PLAYER_PENDING_MERGE AFTER INSERT ON structs.player
     FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_PENDING_MERGE();


    CREATE OR REPLACE FUNCTION structs.PLAYER_INTERNAL_PENDING()
        RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO signer.role(guild_id, status) VALUES (
                NEW.guild_id,
                (CASE WHEN NEW.primary_address IS NULL THEN 'stub' ELSE 'pending' END)::structs.signer_role_status
            ) RETURNING id INTO NEW.role_id;
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER PLAYER_INTERNAL_PENDING BEFORE INSERT ON structs.player_internal_pending
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_INTERNAL_PENDING();



    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_JOIN_PROXY()
        RETURNS trigger AS
    $BODY$
    BEGIN
        -- 16 represents the Association permission
        PERFORM signer.CREATE_TRANSACTION(NEW.guild_id,16,'guild-membership-join-proxy',jsonb_build_array(NEW.primary_address,NEW.pubkey,NEW.signature),'{}');
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER PLAYER_PENDING_JOIN_PROXY AFTER INSERT ON structs.player_pending
        FOR EACH ROW EXECUTE PROCEDURE structs.PLAYER_PENDING_JOIN_PROXY();



COMMIT;

