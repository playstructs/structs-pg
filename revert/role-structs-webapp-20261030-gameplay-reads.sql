-- Revert structs-pg:role-structs-webapp-20261030-gameplay-reads from pg
BEGIN;
REVOKE SELECT ON
    structs.planet_raid,
    structs.planet_attribute,
    structs.planet_activity,
    view.struct_status,
    structs.address_tag,
    structs.banned_word,
    structs.guild_membership_application,
    structs.stat_capacity,
    structs.stat_connection_capacity,
    structs.stat_connection_count,
    structs.stat_fuel,
    structs.stat_load,
    structs.stat_ore,
    structs.stat_power,
    structs.stat_struct_health,
    structs.stat_struct_status,
    structs.stat_structs_load
FROM structs_webapp;
COMMIT;
