-- Verify structs-pg:table-ledger-20261029-denomination-identity on pg
BEGIN;
DO $$
BEGIN
    IF NOT has_table_privilege('structs_indexer','structs.ledger','SELECT')
       OR NOT has_table_privilege('structs_indexer','structs.ledger','INSERT') THEN
        RAISE EXCEPTION 'indexer requires SELECT and INSERT on ledger';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_index i WHERE i.indexrelid='structs.ledger_source_event_uidx'::regclass
          AND i.indrelid='structs.ledger'::regclass AND i.indisunique AND i.indisvalid AND i.indimmediate
          AND i.indpred IS NULL AND i.indexprs IS NULL
          AND (SELECT array_agg(a.attname::text ORDER BY k.n)
                 FROM unnest(i.indkey) WITH ORDINALITY k(num,n)
                 JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.num
                WHERE k.n<=i.indnkeyatts) = ARRAY['time','chain_id','tx_index','msg_index','event_index','denom']
    ) OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='structs.ledger'::regclass
        AND conname='ledger_source_denom_required' AND convalidated) THEN
        RAISE EXCEPTION 'denomination-v1 ledger contract missing or invalid';
    END IF;
END $$;
ROLLBACK;
