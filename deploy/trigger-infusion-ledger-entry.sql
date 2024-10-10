-- Deploy structs-pg:trigger-infusion-ledger-entry to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.INFUSION_LEDGER_ENTRY()
      RETURNS trigger AS
    $BODY$
    DECLARE
        current_block_height BIGINT;
    BEGIN

        SELECT height INTO current_block_height FROM structs.current_block;

        IF TG_OP = 'INSERT' THEN
            INSERT INTO structs.ledger(object_id, address, amount, block_height, updated_at, created_at, action, direction, denom) VALUES(NEW.destination_id || '-' || NEW.address, NEW.address,NEW.fuel, current_block_height, NOW(), NOW(), 'infused', 'debit', 'alpha');

        ELSIF TG_OP = 'UPDATE' THEN
            IF NEW.fuel <> OLD.fuel THEN
                INSERT INTO structs.ledger(object_id, address, amount, block_height, updated_at, created_at, action, direction, denom) VALUES(NEW.destination_id || '-' || NEW.address, NEW.address, NEW.fuel - OLD.fuel, current_block_height, NOW(), NOW(), 'infused', 'debit', 'alpha');
            END IF;

            IF NEW.defusing <> OLD.defusing THEN
                INSERT INTO structs.ledger(object_id, address, amount, block_height, updated_at, created_at, action, direction, denom) VALUES(NEW.destination_id || '-' || NEW.address, NEW.address, NEW.defusing - OLD.defusing, current_block_height, NOW(), NOW(), 'defused', 'credit', 'alpha');
            END IF;

        END IF;

        RETURN NEW;
    END
    $BODY$
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER
      COST 100;

    CREATE TRIGGER ADD_INFUSION_LEDGER_ENTRY AFTER INSERT OR UPDATE ON structs.infusion
     FOR EACH ROW EXECUTE PROCEDURE structs.INFUSION_LEDGER_ENTRY();


COMMIT;

