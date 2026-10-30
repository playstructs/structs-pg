#!/usr/bin/env python3
"""Decode actual SQL queue arguments with the staged v0.22 AutoCLI.

Uses only unsigned, offline --generate-only output. The public creator fixture
is an address, never a key name. Does not sign, simulate or broadcast, and does
not establish on-chain authorization. All disposable SQL fixtures roll back.
"""
import importlib.util
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent
DATABASE = "structs-v022-pg"
NODE = "docker-structs-guild-structsd-1"
BINARY = "/root/.structs/cosmovisor/upgrades/v0.22.0/bin/structsd"
BINARY_SHA256 = "3694dcaca53bf541c9bf311de7cd88fe734f7eb69fe8b68cad8b1ed2a6f5c4c1"
CREATOR = "structs1ul8sd7nk573aw2gyzzwn2ahxqzrq0qg70en5e9"


def run(args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=20)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()


def main():
    assert run(["docker", "inspect", "--format", '{{index .Config.Labels "structs.task"}}', DATABASE]) == "v022-integration"
    assert run(["docker", "exec", NODE, BINARY, "version"]) == "0.22.0"
    digest = run(["docker", "exec", NODE, "sha256sum", BINARY]).split()[0]
    assert digest == BINARY_SHA256, "staged executable differs from the verified linux/amd64 release"
    spec = importlib.util.spec_from_file_location("signer_sessions", ROOT / "v022-signer-concurrency.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    session = module.Session(DATABASE)
    try:
        session.query("BEGIN;\n" + (ROOT / "fixtures/v022-signer.sql").read_text() + """
            INSERT INTO structs.player(id,primary_address,guild_id,guild_rank)
                VALUES('1-990943','membershipkeyc','',20);
        """)
        actor = "1-990940"
        guild = "0-990940"
        allocation = "6-990940"
        station = "4-990940"
        target = "1-990943"
        cases = []
        for allocation_type in ["static", "dynamic", "automated", "providerAgreement"]:
            power = "0" if allocation_type == "automated" else "18446744073709551615"
            cases.append(("allocation_create", "AllocationCreate",
                          f"'{actor}','{allocation_type}','{actor}',{power},'{guild}'",
                          {"sourceObjectId": actor, "controller": guild, "allocationType": allocation_type, "power": power}))
        cases += [
            ("allocation_connect", "SubstationAllocationConnect", f"'{actor}','{allocation}','{station}'", {"allocationId": allocation, "destinationId": station}),
            ("allocation_disconnect", "SubstationAllocationDisconnect", f"'{actor}','{allocation}'", {"allocationId": allocation}),
            ("allocation_delete", "AllocationDelete", f"'{actor}','{allocation}'", {"allocationId": allocation}),
            ("allocation_transfer", "AllocationTransfer", f"'{actor}','{allocation}','{guild}'", {"allocationId": allocation, "controller": guild}),
            ("allocation_update", "AllocationUpdate", f"'{actor}','{allocation}',18446744073709551615", {"allocationId": allocation, "power": "18446744073709551615"}),
            ("substation_create", "SubstationCreate", f"'{actor}','{allocation}'", {"owner": actor, "allocationId": allocation}),
            ("substation_create", "SubstationCreate", f"'{actor}','{allocation}','{guild}'", {"owner": guild, "allocationId": allocation}),
            ("substation_delete", "SubstationDelete", f"'{actor}','{station}','4-990941'", {"substationId": station, "migrationSubstationId": "4-990941"}),
            ("substation_delete", "SubstationDelete", f"'{actor}','{station}',NULL", {"substationId": station, "migrationSubstationId": ""}),
            ("substation_player_connect", "SubstationPlayerConnect", f"'{actor}','{station}','{target}'", {"substationId": station, "playerId": target}),
            ("substation_player_disconnect", "SubstationPlayerDisconnect", f"'{actor}','{station}','{target}'", {"playerId": target}),
            ("substation_player_migrate", "SubstationPlayerMigrate", f"'{actor}','{station}',ARRAY['{actor}','{target}']::varchar[]", {"substationId": station, "playerId": [actor, target]}),
            ("substation_update_name", "SubstationUpdateName", f"'{actor}','{station}','Power station'", {"substationId": station, "name": "Power station"}),
            ("substation_update_pfp", "SubstationUpdatePfp", f"'{actor}','{station}','https://example.com/picture.png'", {"substationId": station, "pfp": "https://example.com/picture.png"}),
        ]
        checked = []
        for wrapper, message_type, arguments, fields in cases:
            session.query(f"SELECT signer.tx_{wrapper}({arguments});")
            request = json.loads(session.query("SELECT to_jsonb(t) FROM signer.tx t ORDER BY id DESC LIMIT 1;"))
            assert request["requested_player_id"] == actor and request["contract"] == "v022-1"
            command = ["docker", "exec", NODE, BINARY, "tx", request["module"], request["command"], *request["args"]]
            for flag, value in request["flags"].items():
                command += ["--" + flag, value]
            # SDK offline unsigned construction requires account/sequence and
            # an empty chain-id. The later signing step binds the actual chain.
            command += ["--generate-only", "--offline", "--account-number", "0", "--sequence", "0",
                        "--chain-id", "", "--from", CREATOR, "--gas", "200000", "--output", "json"]
            unsigned = json.loads(run(command))
            expected = {"@type": "/structs.structs.Msg" + message_type, "creator": CREATOR, **fields}
            assert unsigned["body"]["messages"] == [expected], (wrapper, unsigned["body"]["messages"], expected)
            assert unsigned["signatures"] == [] and unsigned["auth_info"]["signer_infos"] == []
            assert unsigned["body"]["unordered"] is False
            checked.append({"command": request["command"], "args": request["args"], "flags": request["flags"], "message": expected})
        print(json.dumps({"binary_sha256": digest, "unsigned_offline_cases": checked, "result": "passed"}, indent=2))
    finally:
        if session.process.poll() is None:
            session.query("ROLLBACK;")
        session.close()


if __name__ == "__main__":
    main()
