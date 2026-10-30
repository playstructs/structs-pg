-- Disposable database only. The caller controls the transaction.
DELETE FROM signer.tx;
DELETE FROM signer.account;
DELETE FROM signer.role;
DELETE FROM structs.current_block;
DELETE FROM sync_state.sync_cursor;
DELETE FROM structs.api_refresh_state;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time,tip_height,status)
VALUES('structstestnet-111',3353000,'2026-10-30T00:00:00Z',3353000,'current');
INSERT INTO structs.current_block(chain,height,tip_height,status)
VALUES('structstestnet-111',3353000,3353000,'current');
UPDATE sync_state.sync_cursor SET last_block_hash=repeat('A',64);
DELETE FROM sync_state.economy_contract;
INSERT INTO sync_state.economy_contract(chain_id,contract,activation_height,last_height,last_block_hash)
VALUES('structstestnet-111','events-v022-1',3353000,3353000,repeat('A',64));
INSERT INTO structs.api_refresh_state(model,source_height,source_time,inventory_authority)
VALUES('inventory',3353000,'2026-10-30T00:00:00Z','current-claims-v1');
INSERT INTO structs.guild(id,owner) VALUES('0-990940','1-990941');
INSERT INTO structs.player(id,primary_address,guild_id,guild_rank) VALUES
    ('1-990940','queuekeya','0-990940',10),('1-990941','queuekeyb','0-990940',10);
INSERT INTO structs.player_address(address,player_id,guild_id,status)
VALUES('queuerestricted','1-990940','0-990940','approved');
INSERT INTO structs.permission(id,object_type,object_index,object_id,player_id,val) VALUES
    ('8-queuekeya@0','address','queuekeya','1-990940','1-990940',33554431),
    ('8-queuekeyb@0','address','queuekeyb','1-990941','1-990941',33554431),
    ('8-queuerestricted@0','address','queuerestricted','1-990940','1-990940',16);
INSERT INTO signer.role(id,player_id,status) VALUES(990940,'1-990940','ready'),(990941,'1-990941','ready');
INSERT INTO signer.account(id,role_id,address,status,updated_at) VALUES
    (990940,990940,'queuekeya','available','2026-10-30T00:00:02Z'),
    (990941,990941,'queuekeyb','available','2026-10-30T00:00:00Z'),
    (990942,990940,'queuerestricted','available','2026-10-30T00:00:01Z');
INSERT INTO structs.provider(id,owner,access_policy) VALUES('10-990940','1-990941','openMarket');
INSERT INTO structs.agreement(id,owner) VALUES('11-990940','0-990940');

