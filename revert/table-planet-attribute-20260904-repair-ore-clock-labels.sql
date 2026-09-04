-- Revert structs-pg:table-planet-attribute-20260904-repair-ore-clock-labels from pg
--
-- Data repair; revert is a no-op. Clearing labels would re-break type filters.

BEGIN;

    -- no-op

COMMIT;
