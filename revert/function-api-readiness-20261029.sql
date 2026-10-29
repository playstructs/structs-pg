-- Revert structs-pg:function-api-readiness-20261029 from pg
-- Revert dependent application readers first; no persistent state is removed.
BEGIN;
DROP FUNCTION structs.api_readiness(TEXT[]);
COMMIT;
