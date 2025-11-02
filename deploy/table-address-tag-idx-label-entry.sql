-- Deploy structs-pg:table-address-tag-idx-label-entry to pg

BEGIN;

CREATE INDEX address_tag_label_entry_idx
    ON structs.address_tag (label, entry);

COMMIT;



