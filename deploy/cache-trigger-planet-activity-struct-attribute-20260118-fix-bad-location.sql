-- Deploy structs-pg:cache-trigger-planet-activity-struct-attribute-20260118-fix-bad-location to pg

BEGIN;

    CREATE OR REPLACE FUNCTION cache.PLANET_ACTIVITY_STRUCT_ATTRIBUTE() RETURNS trigger AS
    $BODY$
    DECLARE
        location_id CHARACTER VARYING;
    BEGIN

        IF TG_OP = 'DELETE' THEN
            CASE NEW.attribute_type
                WHEN 'typeCount' THEN
                -- Nothing to do here

                WHEN 'protectedStructIndex' THEN
                    -- OLD.val - Struct Index no longer being protected
                    -- NEW.val - Struct Index now being protected
                    -- NEW.object_id - Defending Struct ID

                    -- We're going to project this activity on the planet of the protected Struct(s)

                    IF COALESCE(OLD.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || OLD.val) INTO location_id;
                        IF location_is IS NOT NULL THEN
                            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_remove',
                                    jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                                        'protected_struct_id', '5-' || OLD.val)
                                   );
                        END IF;
                    END IF;

                WHEN 'status' THEN
                -- Shouldn't need a final status emit

                WHEN 'health' THEN
                -- Health is covered via the battle actions

                WHEN 'blockStartBuild' THEN
                -- Covered by Status changes to offline

                WHEN 'blockStartOreMine' THEN
                -- Covered by Status changes to offline

                WHEN 'blockStartOreRefine' THEN
                -- Covered by Status changes to offline
                END CASE;

        ELSE -- Insert and Update

            CASE NEW.attribute_type
                WHEN 'typeCount' THEN
                -- Nothing to do here

                WHEN 'protectedStructIndex' THEN
                    -- OLD.val - Struct Index no longer being protected
                    -- NEW.val - Struct Index now being protected
                    -- NEW.object_id - Defending Struct ID

                    -- We're going to project this activity on the planet of the protected Struct(s)

                    IF COALESCE(OLD.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || OLD.val) INTO location_id;
                        IF location_id IS NOT NULL THEN
                            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_remove',
                                    jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                                        'protected_struct_id', '5-' || OLD.val)
                                   );
                        END IF;
                    END IF;

                    IF COALESCE(NEW.val,0) > 0 THEN
                        SELECT structs.GET_ACTIVITY_LOCATION_ID('5-' || NEW.val) INTO location_id;
                        IF location_id IS NOT NULL THEN
                            INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                            VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_defense_add',
                                    jsonb_build_object( 'defender_struct_id', NEW.object_id,
                                                        'protected_struct_id', '5-' || NEW.val)
                                   );
                        END IF;
                    END IF;

                WHEN 'status' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    IF location_id  IS NOT NULL THEN
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_status',
                                jsonb_build_object( 'struct_id', NEW.object_id,
                                                    'status', NEW.val,
                                                    'status_old', OLD.val)
                               );
                    END IF;
                WHEN 'health' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    IF location_id IS NOT NULL THEN
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_health',
                                jsonb_build_object( 'struct_id', NEW.object_id,
                                                    'health', NEW.val,
                                                    'health_old', OLD.val)
                               );
                    END IF;
                WHEN 'blockStartBuild' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    IF location_id IS NOT NULL THEN
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_build_start',
                                jsonb_build_object( 'struct_id', NEW.object_id,
                                                    'block', NEW.val)
                               );
                    END IF;
                WHEN 'blockStartOreMine' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    IF location_id IS NOT NULL THEN
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_ore_mine_start',
                                jsonb_build_object( 'struct_id', NEW.object_id,
                                                    'block', NEW.val)
                               );
                    END IF;
                WHEN 'blockStartOreRefine' THEN
                    SELECT structs.GET_ACTIVITY_LOCATION_ID(NEW.object_id) INTO location_id;
                    IF location_id IS NOT NULL THEN
                        INSERT INTO structs.planet_activity(time, seq, planet_id, category, detail)
                        VALUES (NOW(), structs.GET_PLANET_ACTIVITY_SEQUENCE(location_id), location_id, 'struct_block_ore_refine_start',
                                jsonb_build_object( 'struct_id', NEW.object_id,
                                                    'block', NEW.val)
                               );
                    END IF;
                END CASE;
        END IF;
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    --CREATE TRIGGER PLANET_ACTIVITY_STRUCT_ATTRIBUTE AFTER INSERT OR UPDATE OR DELETE ON structs.struct_attribute
    --    FOR EACH ROW EXECUTE PROCEDURE cache.PLANET_ACTIVITY_STRUCT_ATTRIBUTE();


COMMIT;


