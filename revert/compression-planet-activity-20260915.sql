-- Revert structs-pg:compression-planet-activity-20260915 from pg
--
-- Removes the policy, decompresses every compressed chunk (one statement per
-- chunk via \gexec, each its own transaction; this reads and rewrites up to
-- ~900 MB and can take minutes), then disables compression.

SELECT remove_compression_policy('structs.planet_activity', if_exists => true);

SELECT format('SELECT decompress_chunk(%L, if_compressed => true);', format('%I.%I', chunk_schema, chunk_name))
  FROM timescaledb_information.chunks
 WHERE hypertable_schema = 'structs' AND hypertable_name = 'planet_activity'
   AND is_compressed
 ORDER BY range_start
\gexec

ALTER TABLE structs.planet_activity SET (timescaledb.compress = false);
