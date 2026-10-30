#!/usr/bin/env python3
"""Exercise actual concurrent claims in a fresh disposable PostgreSQL container.

Requires only Python and Docker. Never targets the running guild database.
"""
import json
import os
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
    docker = ["docker", "exec", "--user", "structs", "-e", "PGHOST=/var/run/postgresql", "-w", "/migration", container]
    sessions = []
    try:
        for attempt in range(30):
            if subprocess.run(docker + ["pg_isready", "-d", "structs"], capture_output=True, timeout=5).returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("disposable PostgreSQL did not become ready")
        print("Deploying the actual Sqitch chain into a fresh isolated container.", flush=True)
        result = subprocess.run(docker + ["sqitch", "deploy", "--verify", "--to",
                                "table-signer-tx-20261030-authority-contract", "db:pg:structs"],
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
        print(json.dumps({"concurrent_claims": 2, "different_accounts": True,
                          "busy_request_stays_pending": True, "duplicate_claim": False,
                          "new_accounts_created": 0, "result": "passed"}))
    finally:
        for session in sessions:
            session.close()
        subprocess.run(["docker", "rm", "-f", "-v", container], check=True, capture_output=True, timeout=15)


if __name__ == "__main__":
    main()
