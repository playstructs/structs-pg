-- Verify structs-pg:role-structs-webapp-20261029-funds on pg
BEGIN;
DO $$
DECLARE source TEXT;
BEGIN
    IF NOT has_schema_privilege('structs_webapp','view','USAGE') THEN
        RAISE EXCEPTION 'missing webapp view schema access';
    END IF;
    FOREACH source IN ARRAY ARRAY['structs.fleet','structs.grid','structs.guild_meta',
        'structs.player_address','view.player_inventory'] LOOP
        IF NOT has_table_privilege('structs_webapp',source,'SELECT') THEN
            RAISE EXCEPTION 'missing webapp source read: %',source;
        END IF;
    END LOOP;
END $$;
ROLLBACK;
