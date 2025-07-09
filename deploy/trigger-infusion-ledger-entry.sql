-- Deploy structs-pg:trigger-infusion-ledger-entry to pg

BEGIN;

    -- This only needs to manage the struct infusions
    CREATE OR REPLACE FUNCTION structs.INFUSION_LEDGER_ENTRY()
      RETURNS trigger AS
    $BODY$
    DECLARE
        current_block_height BIGINT;
    BEGIN
        IF NEW.destination_type = 'struct' THEN
            SELECT height INTO current_block_height FROM structs.current_block;

            IF TG_OP = 'INSERT' THEN
                INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES( NEW.address, NEW.destination_id, NEW.fuel_p, current_block_height, NOW(), 'infused', 'debit', 'ualpha');
                INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES( NEW.address, NEW.destination_id, NEW.fuel_p, current_block_height, NOW(), 'infused', 'credit', 'ualpha.infused');
            ELSIF TG_OP = 'UPDATE' THEN
                IF NEW.fuel_p <> OLD.fuel_p THEN
                    INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES( NEW.address, NEW.destination_id, NEW.fuel_p - OLD.fuel_p, current_block_height, NOW(), 'infused', 'debit', 'ualpha');
                    INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES( NEW.address, NEW.destination_id, NEW.fuel_p - OLD.fuel_p, current_block_height, NOW(), 'infused', 'credit', 'ualpha.infused');
                END IF;
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

