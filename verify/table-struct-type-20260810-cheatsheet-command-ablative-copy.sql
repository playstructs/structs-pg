-- Verify structs-pg:table-struct-type-20260810-cheatsheet-command-ablative-copy on pg

BEGIN;

    DO $$
    BEGIN
        ASSERT (SELECT passive_weaponry_label = 'Chimera Counter'
                       AND passive_weaponry_description = 'Only targets Structs in the same Battleground.'
                FROM structs.struct_type_cs
                WHERE class = 'Command Ship' AND language = 'EN'),
            'struct_type_cs Command Ship passive weaponry not set';

        ASSERT (SELECT bool_and(unit_defenses_description = 'Reduces direct attack DMG by 1.')
                FROM structs.struct_type_cs
                WHERE unit_defenses_label = 'Ablative Armour' AND language = 'EN'),
            'struct_type_cs Ablative Armour description not set';

        ASSERT (SELECT bool_and(passive_weaponry_label = 'Chimera Counter'
                                AND passive_weaponry_description = 'Only targets Structs in the same Battleground.')
                FROM structs.struct_type
                WHERE class = 'Command Ship'),
            'struct_type Command Ship passive weaponry not synced';

        ASSERT (SELECT bool_and(unit_defenses_description = 'Reduces direct attack DMG by 1.')
                FROM structs.struct_type
                WHERE unit_defenses_label = 'Ablative Armour'),
            'struct_type Ablative Armour description not synced';
    END
    $$;

ROLLBACK;
