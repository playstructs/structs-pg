#!/usr/bin/env python3
"""Verify signed-history recovery in isolated replacements of the test database.

Requires the fully migrated, labelled structs-v022-pg test container. No live
database is changed. This is a functional restore test, not a volume rehearsal.
"""
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid


SOURCE = "structs-v022-pg"
ROOT = Path(__file__).resolve().parent.parent


def run(args, *, stdin=None, check=True):
    result = subprocess.run(args, input=stdin, text=True, capture_output=True, timeout=60)
    if check and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


def command(container):
    # The image's default TCP credentials are not the running test container's.
    # Use its existing local socket, and never wait for a password prompt.
    return ["docker", "exec", "-i", "-u", "structs", "-e", "PGHOST=/var/run/postgresql",
            "-w", "/migration", container]


def sql(container, statement):
    return run(command(container) + ["psql", "-XqAt", "-w", "-v", "ON_ERROR_STOP=1", "-d", "structs"],
               stdin=statement).stdout.strip()


def sqitch(container, *args, gate=True, check=True):
    prefix = command(container)[:-1]
    if gate:
        prefix += ["-e", "PGOPTIONS=-c structs.signer_contract=v022-1"]
    return run(prefix + [container, "sqitch", *args, "db:pg:structs"], check=check)


def main():
    if run(["docker", "inspect", "--format", '{{index .Config.Labels "structs.task"}}', SOURCE]).stdout.strip() != "v022-integration":
        raise RuntimeError("refusing a source without the disposable-test label")
    image = run(["docker", "inspect", "--format", "{{.Image}}", SOURCE]).stdout.strip()
    containers = []

    def restore(source):
        target = "structs-v022-restore-" + uuid.uuid4().hex[:12]
        run(["docker", "run", "--pull=never", "-d", "--name", target, "--label", "structs.task=v022-integration",
             "-v", f"{ROOT}:/migration:ro", "--entrypoint", "/usr/bin/pg_ctlcluster", image,
             "--foreground", "18", "main", "start"])
        containers.append(target)
        for _ in range(30):
            if run(command(target) + ["pg_isready", "-d", "structs"], check=False).returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("restore target did not become ready")
        # Database archives refer to cluster roles but do not create them. The
        # fixture needs identities for ACLs, not login credentials. Never export
        # passwords into the test log or alter a source role.
        source_roles = set(sql(source, "SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%';").splitlines())
        target_roles = set(sql(target, "SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%';").splitlines())
        for role in sorted(source_roles - target_roles):
            sql(target, 'CREATE ROLE "' + role.replace('"', '""') + '" NOLOGIN;')
        extension = json.loads(sql(source, """SELECT json_build_object('schema',n.nspname,'version',e.extversion)
            FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='timescaledb';"""))
        schema = '"' + extension["schema"].replace('"', '""') + '"'
        version = "'" + extension["version"].replace("'", "''") + "'"
        with tempfile.TemporaryDirectory(prefix="v022-restore-") as work:
            archive = Path(work) / "backup.dump"
            with archive.open("wb") as output:
                subprocess.run(command(source) + ["pg_dump", "-w", "-Fc", "-d", "structs"],
                               stdout=output, stderr=subprocess.PIPE, check=True, timeout=60)
            run(["docker", "cp", str(archive), target + ":/tmp/v022-backup.dump"])
            listing = run(command(target) + ["pg_restore", "--list", "/tmp/v022-backup.dump"]).stdout.splitlines()
            schema_rows = [line for line in listing if re.match(r"^\d+; \d+ \d+ SCHEMA - ", line)]
            # Install archive schema names/owners first so the extension has the
            # original schema. Restore every remaining archive entry afterwards.
            # The source installs Timescale in structs, not the public default.
            for filename, rows in [("schemas.list", schema_rows), ("remaining.list", [line for line in listing if line not in schema_rows])]:
                file = Path(work) / filename
                file.write_text("\n".join(rows) + "\n")
                run(["docker", "cp", str(file), target + ":/tmp/" + filename])
            run(command(target) + ["pg_restore", "-w", "--exit-on-error", "--use-list=/tmp/schemas.list", "-d", "structs", "/tmp/v022-backup.dump"])
            sql(target, f"CREATE EXTENSION timescaledb WITH SCHEMA {schema} VERSION {version}; SELECT {schema}.timescaledb_pre_restore();")
            run(command(target) + ["pg_restore", "-w", "--exit-on-error", "--use-list=/tmp/remaining.list", "-d", "structs", "/tmp/v022-backup.dump"])
            sql(target, f"SELECT {schema}.timescaledb_post_restore();")
        return target

    try:
        current = restore(SOURCE)
        inventory = """SELECT json_agg(json_build_object('name',proname,'definition',pg_get_functiondef(oid),
            'owner',pg_get_userbyid(proowner),'acl',proacl::text) ORDER BY proname) FROM pg_proc
            WHERE pronamespace='signer'::regnamespace AND proname IN ('transaction_error','transaction_broadcast_results');"""
        functions = json.loads(sql(current, inventory))
        sqitch(current, "revert", "--to", "function-signer-tx-20261030-registration", "-y")
        previous = json.loads(sql(current, inventory))
        assert all("contract" not in item["definition"] for item in previous), previous
        assert [(x["owner"], x["acl"]) for x in previous] == [(x["owner"], x["acl"]) for x in functions]
        denied = sqitch(current, "deploy", "--verify", gate=False, check=False)
        assert denied.returncode and "submission lifecycle requires" in denied.stdout + denied.stderr
        sqitch(current, "deploy", "--verify")
        assert json.loads(sql(current, inventory)) == functions
        sql(current, (ROOT / "tests/fixtures/v022-signer.sql").read_text())
        sql(current, """SELECT signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse','[]','{}',
            '[{"check_type":"object","object_id":"1-990940","permission":32}]'); SELECT signer.CLAIM_TRANSACTION_V022();
            SELECT signer.SAVE_SIGNED_TRANSACTION_V022(id,claim_token,'restore-proof'::bytea,
                18446744073709551615,9007199254740993,3353000,0) FROM signer.tx;
            SELECT signer.BEGIN_SUBMISSION_V022(id,claim_token) FROM signer.tx;
            SELECT signer.MARK_SUBMISSION_UNKNOWN_V022(id,claim_token,'restored uncertain send') FROM signer.tx;""")
        snapshot = """SELECT jsonb_build_object('request',(SELECT to_jsonb(t) FROM signer.tx t),
            'source_coverage',(SELECT to_jsonb(e) FROM sync_state.economy_contract e),
            'submission',(SELECT signer.SUBMISSION_V022(tx_id) FROM signer.tx_submission),
            'account',(SELECT to_jsonb(a) FROM signer.account a WHERE id=990940));"""
        before = json.loads(sql(current, snapshot))
        refused = sqitch(current, "revert", "--to", "function-signer-tx-20261030-registration", "-y", check=False)
        assert refused.returncode and "cannot discard recorded economy source coverage" in refused.stdout + refused.stderr
        refused = subprocess.run(command(current) + ["psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", "structs", "-f",
                                 "/migration/revert/table-signer-tx-20261030-submission.sql"],
                                 capture_output=True, text=True, timeout=60)
        assert refused.returncode and "signed history exists" in refused.stdout + refused.stderr
        assert json.loads(sql(current, snapshot)) == before
        recovered = restore(current)
        assert json.loads(sql(recovered, snapshot)) == before
        assert sql(recovered, "SELECT signer.BEGIN_SUBMISSION_V022(tx_id,claim_token) FROM signer.tx_submission;") == "f"
        assert sql(recovered, "SELECT signer.CLAIM_TRANSACTION_V022();") == ""
        sqitch(recovered, "verify", "--from", "table-signer-tx-20261030-submission")

        # Restore a managed key with both an unsigned aborted attempt and an
        # uncertain signed successor. Backup recovery may neither renew it nor
        # activate it until that same signed identity is confirmed and indexed.
        sqitch(recovered, "deploy", "--verify")
        address = "structs1" + "p" * 38
        context = json.dumps({"chain_id": "structstestnet-111", "protocol": "v0.22.0", "source_height": "3353000",
                              "player_id": "1-990940", "address": address, "proof_nonce": "0",
                              "registered_player_id": "", "timeout_height": "0"})
        sql(recovered, "INSERT INTO signer.account(id,role_id,status) VALUES(990950,990940,'generating');")
        managed = json.loads(sql(recovered, f"""SELECT signer.UPDATE_PENDING_ACCOUNT(990950,'1-990940','{address}',
            '02' || repeat('ab',32),repeat('cd',64),16,'{context}');"""))
        claim = json.loads(sql(recovered, "SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert claim["transaction"]["id"] == managed["id"]
        sql(recovered, f"SELECT signer.ABORT_UNSENT_TRANSACTION_V022({managed['id']},'{claim['transaction']['claim_token']}','restore nonce refresh');")
        renewed = json.loads(sql(recovered, f"SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,{managed['id']},repeat('ef',64),'{context}');"))
        claim = json.loads(sql(recovered, "SELECT signer.CLAIM_TRANSACTION_V022();"))
        assert claim["transaction"]["id"] == renewed["id"]
        token = claim["transaction"]["claim_token"]
        saved = json.loads(sql(recovered, f"SELECT signer.SAVE_SIGNED_TRANSACTION_V022({renewed['id']},'{token}','managed-restore'::bytea,0,0,3353000,0);"))
        sql(recovered, f"SELECT signer.BEGIN_SUBMISSION_V022({renewed['id']},'{token}'); SELECT signer.MARK_SUBMISSION_UNKNOWN_V022({renewed['id']},'{token}','restore interrupted send');")
        managed_snapshot = """SELECT jsonb_build_object(
            'accounts',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM signer.account a),
            'requests',(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM signer.tx t),
            'history',(SELECT jsonb_agg(to_jsonb(h) ORDER BY tx_id) FROM signer.account_registration h),
            'proofs',(SELECT jsonb_agg(to_jsonb(p) ORDER BY tx_id) FROM signer.tx_registration_proof p),
            'submissions',(SELECT jsonb_agg(to_jsonb(s) ORDER BY tx_id) FROM signer.tx_submission s),
            'aborts',(SELECT jsonb_agg(to_jsonb(a) ORDER BY tx_id) FROM signer.tx_unsent_abort a));"""
        expected = json.loads(sql(recovered, managed_snapshot))
        managed_recovered = restore(recovered)
        assert json.loads(sql(managed_recovered, managed_snapshot)) == expected
        assert sql(managed_recovered, f"SELECT signer.BEGIN_SUBMISSION_V022({renewed['id']},'{token}');") == "f"
        denied = run(command(managed_recovered) + ["psql", "-XqAt", "-v", "ON_ERROR_STOP=1", "-d", "structs", "-c",
                     f"SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,{renewed['id']},repeat('ef',64),'{context}');"], check=False)
        assert denied.returncode and "outcome is uncertain" in denied.stderr
        assert json.loads(sql(managed_recovered, managed_snapshot)) == expected
        receipt = json.dumps({"stage": "deliver_tx", "hash": saved["tx_hash"], "code": "0", "codespace": "", "log": "",
                              "height": "3353000", "index": "0", "block_hash": "D" * 64})
        sql(managed_recovered, f"SELECT signer.RECORD_SUBMISSION_RESULT_V022({renewed['id']},'{token}','{receipt}');")
        sql(managed_recovered, f"""INSERT INTO structs.player_address(address,player_id,status) VALUES('{address}','1-990940','approved');
            INSERT INTO structs.permission(id,val) VALUES('8-{address}@0',16);""")
        active = json.loads(sql(managed_recovered, f"SELECT signer.ACTIVATE_ACCOUNT_V022(990950,{renewed['id']});"))
        assert active["status"] == "available" and active["registration_tx_id"] == renewed["id"]
        sqitch(managed_recovered, "verify", "--from", "function-signer-account-20261030-registration-lifecycle")
        print(json.dumps({"activation_gate": True, "empty_revert_redeploy": True, "owner_acl_preserved": True,
                          "populated_revert_refused": True, "signed_history_restored": True,
                          "exact_uint64_preserved": True, "unknown_key_reserved": True,
                          "restored_resend_permit": False, "managed_attempts_and_aborts_restored": True,
                          "managed_unknown_renewal_refused": True, "managed_confirmed_activation": True,
                          "result": "passed"}))
    finally:
        for container in containers:
            run(["docker", "rm", "-f", "-v", container])


if __name__ == "__main__":
    main()
