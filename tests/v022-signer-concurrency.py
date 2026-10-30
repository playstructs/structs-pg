#!/usr/bin/env python3
"""Exercise actual concurrent claims in a fresh disposable PostgreSQL container.

Requires only Python and Docker. Never targets the running guild database.
"""
import json
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import select
import subprocess
import time
import uuid


SOURCE_CONTAINER = "structs-v022-pg"


class Session:
    def __init__(self, container):
        self.process = subprocess.Popen(
            ["docker", "exec", "-i", "--user", "structs", "-e", "PGHOST=/var/run/postgresql",
             container, "psql", "-XqAt", "-v", "ON_ERROR_STOP=1", "-d", "structs"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0,
        )
        self.buffer = b""

    def query(self, sql):
        marker = ("done_" + uuid.uuid4().hex).encode()
        self.process.stdin.write(sql.encode() + b"\n\\echo " + marker + b"\n")
        self.process.stdin.flush()
        deadline = time.monotonic() + 15
        while marker + b"\n" not in self.buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                raise RuntimeError("SQL session timed out: " + self.buffer.decode())
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError("SQL session ended: " + self.buffer.decode())
            self.buffer += chunk
        output, _, self.buffer = self.buffer.partition(marker + b"\n")
        return output.decode().strip()

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)


def main():
    label = subprocess.check_output(
        ["docker", "inspect", "--format", '{{index .Config.Labels "structs.task"}}', SOURCE_CONTAINER], text=True,
    ).strip()
    if label != "v022-integration":
        raise RuntimeError("refusing to use a container without the disposable-test label")
    image = subprocess.check_output(["docker", "inspect", "--format", "{{.Image}}", SOURCE_CONTAINER], text=True).strip()
    container = "structs-v022-signer-" + uuid.uuid4().hex[:12]
    root = Path(__file__).resolve().parent.parent
    subprocess.run(["docker", "run", "--pull=never", "-d", "--name", container,
                    "--label", "structs.task=v022-integration", "-v", f"{root}:/migration:ro",
                    "--entrypoint", "/usr/bin/pg_ctlcluster", image,
                    "--foreground", "18", "main", "start"], check=True, capture_output=True, timeout=30)
    docker = ["docker", "exec", "--user", "structs", "-e", "PGHOST=/var/run/postgresql",
              "-e", "PGOPTIONS=-c structs.ledger_writer_contract=denomination-v1 -c structs.signer_contract=v022-1",
              "-w", "/migration", container]
    sessions = []
    try:
        for attempt in range(30):
            if subprocess.run(docker + ["pg_isready", "-d", "structs"], capture_output=True, timeout=5).returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("disposable PostgreSQL did not become ready")
        print("Deploying the actual Sqitch chain into a fresh isolated container.", flush=True)
        result = subprocess.run(docker + ["sqitch", "deploy", "--verify", "db:pg:structs"],
                                capture_output=True, text=True, timeout=240)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        first, second, observer = [Session(container) for _ in range(3)]
        sessions = [first, second, observer]
        # Reuse only fixture setup, not the functional assertions. Its deletion
        # statements are confined to this disposable container.
        setup = "BEGIN;\n" + (Path(__file__).parent / "fixtures/v022-signer.sql").read_text()
        first.query(setup + "\nCOMMIT;")
        ids = []
        for player in ["1-990940", "1-990940", "1-990941"]:
            ids.append(int(first.query(f"""
                SELECT signer.CREATE_TRANSACTION_V022('{player}','{player}','structs','reactor-infuse',
                    '[]','{{}}','[{{"check_type":"object","object_id":"{player}","permission":32}}]')->>'id';
            """)))
        a = json.loads(first.query("BEGIN; SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert int(a["transaction"]["id"]) == ids[0] and a["account"]["address"] == "queuekeya", a
        # A holds both locks. B must skip A's other request (same locked key)
        # and claim the independent player's request without waiting for A.
        b = json.loads(second.query("BEGIN; SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert int(b["transaction"]["id"]) == ids[2] and b["account"]["address"] == "queuekeyb", b
        assert a["transaction"]["claim_token"] != b["transaction"]["claim_token"]
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        second.query("COMMIT;")
        first.query("COMMIT;")
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        assert observer.query(f"SELECT status FROM signer.tx WHERE id={ids[1]};") == "pending"
        assert observer.query("SELECT count(*) FROM signer.account;") == "3"
        # The extended rule must also re-read a committed target-grant change
        # made by another connection before the claim statement starts.
        first.query("""
            DELETE FROM signer.tx;
            UPDATE signer.account SET status='available';
            UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
            INSERT INTO structs.player_address(address,player_id,status)
                VALUES('concurrencytarget','1-990940','approved');
            INSERT INTO structs.permission(id,val) VALUES('8-concurrencytarget@0',16);
            SELECT signer.tx_permission_set_on_address('1-990940','concurrencytarget',16);
        """)
        second.query("UPDATE structs.permission SET val=80 WHERE id='8-concurrencytarget@0';")
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        first.query("UPDATE structs.permission SET val=80 WHERE id='8-queuekeya@0';")
        changed = json.loads(observer.query("SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert changed["account"]["address"] == "queuekeya", changed

        # Two account-agent retries must serialize on their managed account and
        # reuse the original proof/request. No second submission is enqueued.
        address = "structs1" + "q" * 38
        context = json.dumps({"chain_id": "structstestnet-111", "protocol": "v0.22.0",
                              "source_height": "3353000", "player_id": "1-990940", "address": address,
                              "proof_nonce": "0", "registered_player_id": "", "timeout_height": "0"})
        first.query("INSERT INTO signer.account(id,role_id,status) VALUES(990947,990940,'generating');")
        registration = f"""SELECT signer.UPDATE_PENDING_ACCOUNT(990947,'1-990940','{address}',
            '02' || repeat('ab',32),repeat('cd',64),16,'{context}'::jsonb);"""
        original = json.loads(first.query("BEGIN; " + registration))
        second_pid = int(second.query("SELECT pg_backend_pid();"))
        with ThreadPoolExecutor(max_workers=1) as pool:
            retry = pool.submit(second.query, "BEGIN; " + registration + " COMMIT;")
            try:
                for attempt in range(100):
                    if observer.query(f"SELECT cardinality(pg_blocking_pids({second_pid}))>0;") == "t":
                        break
                    if retry.done():
                        raise AssertionError("managed retry did not wait for the original account claim")
                    time.sleep(0.05)
                else:
                    raise AssertionError("managed retry did not reach its account lock")
            finally:
                first.query("COMMIT;")
            repeated = json.loads(retry.result(timeout=10))
        assert original["id"] == repeated["id"]
        assert observer.query(f"SELECT count(*) FROM signer.tx_registration_proof WHERE address='{address}';") == "1"
        assert observer.query("SELECT status FROM signer.account WHERE id=990947;") == "pending"

        # A committed send marker grants one transport attempt, even when two
        # recovering workers reach it together. No wall-clock lease unlocks it.
        tx_id = changed["transaction"]["id"]
        token = changed["transaction"]["claim_token"]
        saved = json.loads(first.query(f"""SELECT signer.SAVE_SIGNED_TRANSACTION_V022(
            {tx_id},'{token}','concurrent-signed'::bytea,18446744073709551615,9007199254740993,3353000,0);"""))
        assert saved["account_number"] == "18446744073709551615"
        start_send = f"SELECT signer.BEGIN_SUBMISSION_V022({tx_id},'{token}');"
        assert first.query("BEGIN; " + start_send) == "t"
        with ThreadPoolExecutor(max_workers=1) as pool:
            retry = pool.submit(second.query, "BEGIN; " + start_send + " COMMIT;")
            try:
                for attempt in range(100):
                    if observer.query(f"SELECT cardinality(pg_blocking_pids({second_pid}))>0;") == "t":
                        break
                    if retry.done():
                        raise AssertionError("second send attempt did not wait for the original marker")
                    time.sleep(0.05)
                else:
                    raise AssertionError("second send attempt did not reach its transaction lock")
            finally:
                first.query("COMMIT;")
            assert retry.result(timeout=10) == "f"
        # A new observer after the committed marker must reconcile, not send.
        assert observer.query(start_send) == "f"
        unknown = json.loads(observer.query(f"SELECT signer.MARK_SUBMISSION_UNKNOWN_V022({tx_id},'{token}','worker restarted');"))
        assert unknown["state"] == "unknown"
        assert observer.query("SELECT status FROM signer.account WHERE id=990940;") == "signing"
        receipt = json.dumps({"stage": "deliver_tx", "hash": saved["tx_hash"], "code": "0",
                              "codespace": "", "log": "", "height": "3353001", "index": "0", "block_hash": "A" * 64})
        committed = json.loads(observer.query(f"SELECT signer.RECORD_SUBMISSION_RESULT_V022({tx_id},'{token}','{receipt}');"))
        assert committed["state"] == "committed"
        assert observer.query("SELECT status FROM signer.account WHERE id=990940;") == "available"

        # Current guild policy and member standing must be re-read after another
        # committed session changes them, not frozen into the request's mask.
        first.query("""
            UPDATE signer.account SET status='signing' WHERE id IN (990940,990942);
            INSERT INTO structs.guild(id,owner,join_infusion_minimum_bypass_by_invite)
                VALUES('0-990945','1-990940','closed');
            SELECT signer.tx_guild_membership_invite('1-990941','0-990945','1-990940','');
        """)
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        second.query("UPDATE structs.guild SET join_infusion_minimum_bypass_by_invite='member' WHERE id='0-990945';")
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        second.query("UPDATE structs.player SET guild_id='0-990945' WHERE id='1-990941';")
        membership = json.loads(observer.query("SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert membership["transaction"]["command"] == "guild-membership-invite"
        assert membership["transaction"]["requested_player_id"] == "1-990941"
        assert membership["account"]["address"] == "queuekeyb"
        observer.query("SELECT signer.ABORT_UNSENT_TRANSACTION_V022(" + str(membership["transaction"]["id"]) +
                       ",'" + membership["transaction"]["claim_token"] + "'::uuid,'membership fixture completed');")
        first.query("""
            INSERT INTO structs.allocation(id,source_id,controller,allocation_type)
                VALUES('6-990945','1-990940','1-990941','dynamic');
            SELECT signer.tx_allocation_update('1-990941','6-990945',1);
        """)
        assert observer.query("SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        second.query("UPDATE structs.allocation SET source_id='1-990941' WHERE id='6-990945';")
        energy = json.loads(observer.query("SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert energy["transaction"]["command"] == "allocation-update"
        assert energy["transaction"]["requested_player_id"] == "1-990941"
        assert energy["account"]["address"] == "queuekeyb"
        print(json.dumps({"concurrent_claims": 2, "different_accounts": True,
                          "busy_request_stays_pending": True, "duplicate_claim": False,
                          "new_accounts_created": 0, "current_grant_rechecked": True,
                          "managed_registration_requests": 1, "concurrent_registration_retry_reused": True,
                          "concurrent_send_permits": 1, "restart_resend_permit": False,
                          "unknown_reserved_key": True, "inclusion_released_key": True,
                          "membership_policy_rechecked": True, "energy_source_rechecked": True,
                          "result": "passed"}))
    finally:
        for session in sessions:
            session.close()
        subprocess.run(["docker", "rm", "-f", "-v", container], check=True, capture_output=True, timeout=15)


if __name__ == "__main__":
    main()
