-- Deploy structs-pg:table-planet-20260525-add-name to pg
--
-- Chain planet name belongs on structs.planet. Retire planet_meta.

BEGIN;

    ALTER TABLE structs.planet
        ADD COLUMN name TEXT;

    UPDATE structs.planet pl
       SET name = pick.name
      FROM (
            SELECT DISTINCT ON (pm.id)
                   pm.id,
                   pm.name
              FROM structs.planet_meta pm
              LEFT JOIN structs.planet p     ON p.id = pm.id
              LEFT JOIN structs.player owner ON owner.id = p.owner
             ORDER BY pm.id,
                      (pm.guild_id IS NOT DISTINCT FROM owner.guild_id) DESC,
                      pm.updated_at DESC
           ) pick
     WHERE pl.id = pick.id;

    DROP TABLE structs.planet_meta CASCADE;

COMMIT;
