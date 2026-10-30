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
        structure = "5-990940"
        target = "5-990941"
        fleet = "9-990940"
        planet = "2-990940"
        maximum = "18446744073709551615"
        proof = "ab" * 32
        nonce = "184467440737095516150000"
        validator = "structsvaloper1" + "q" * 32 + "3u5j96"
        cases = [
            ("explore", "PlanetExplore", f"'{actor}'", {"playerId": actor, "name": ""}),
            ("fleet_move", "FleetMove", f"'{actor}','{fleet}','{planet}'", {"fleetId": fleet, "destinationLocationId": planet}),
            ("planet_raid_complete", "PlanetRaidComplete", f"'{actor}','{fleet}','{proof}','{nonce}'", {"fleetId": fleet, "proof": proof, "nonce": nonce}),
            ("reactor_restart", "ReactorRestart", f"'{actor}','{validator}'", {"validator_address": validator}),
            ("struct_build_initiate", "StructBuildInitiate", f"'{actor}',{maximum},'land',{maximum}", {"playerId": actor, "structTypeId": maximum, "operatingAmbit": "land", "slot": maximum}),
            ("struct_move", "StructMove", f"'{actor}','{structure}','fleet','space',{maximum}", {"structId": structure, "locationType": "fleet", "ambit": "space", "slot": maximum}),
            ("struct_attack", "StructAttack", f"'{actor}','{structure}','{target},{target}','primaryWeapon'", {"operatingStructId": structure, "targetStructId": [target,target], "weaponSystem": "primaryWeapon"}),
            ("struct_defense_set", "StructDefenseSet", f"'{actor}','{structure}','{target}'", {"defenderStructId": structure, "protectedStructId": target}),
            ("struct_defense_clear", "StructDefenseClear", f"'{actor}','{structure}'", {"defenderStructId": structure}),
        ]
        for action, message in [("activate","Activate"),("deactivate","Deactivate"),("build_cancel","BuildCancel"),("stealth_activate","StealthActivate"),("stealth_deactivate","StealthDeactivate")]:
            cases.append(("struct_"+action,"Struct"+message,f"'{actor}','{structure}'",{"structId":structure}))
        for action, message in [("build_complete","BuildComplete"),("ore_mine_complete","OreMinerComplete"),("ore_refine_complete","OreRefineryComplete")]:
            cases.append(("struct_"+action,"Struct"+message,f"'{actor}','{structure}','{proof}','{nonce}'",{"structId":structure,"proof":proof,"nonce":nonce}))
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
