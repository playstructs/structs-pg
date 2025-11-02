-- Revert structs-pg:table-address-tag-idx-label-entry from pg

BEGIN;

DROP INDEX IF EXISTS structs.address_tag_label_entry_idx;

COMMIT;
