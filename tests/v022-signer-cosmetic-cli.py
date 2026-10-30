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
                VALUES('1-990943','cosmetickeyc','0-990940',20);
            INSERT INTO structs.planet(id,owner) VALUES('2-990940','1-990943');
            INSERT INTO structs.substation(id,owner) VALUES('4-990940','0-990940');
        """)
        actor = "1-990940"
        guild = "0-990940"
        target = "1-990943"
        station = "4-990940"
        planet = "2-990940"
        picture = "https://example.com/picture.png"
        cases = [
            ("guild_update_name", "GuildUpdateName", f"'{actor}','{guild}','New guild'", {"guildId": guild, "name": "New guild"}),
            ("guild_update_pfp", "GuildUpdatePfp", f"'{actor}','{guild}','{picture}'", {"guildId": guild, "pfp": picture}),
            ("guild_update_entry_substation_id", "GuildUpdateEntrySubstationId", f"'{actor}','{guild}','{station}'", {"guildId": guild, "entrySubstationId": station}),
            ("guild_update_entry_substation_id", "GuildUpdateEntrySubstationId", f"'{actor}','{guild}',NULL", {"guildId": guild, "entrySubstationId": ""}),
            ("player_update_name", "PlayerUpdateName", f"'{actor}','Player'", {"playerId": actor, "name": "Player"}),
            ("player_update_pfp", "PlayerUpdatePfp", f"'{actor}','{picture}'", {"playerId": actor, "pfp": picture}),
            ("player_update_pfp_cr_attributes", "PlayerUpdatePfpClientRenderAttributes", f"'{actor}','{{}}'", {"playerId": actor, "pfpClientRenderAttributes": "{}"}),
            ("planet_update_name", "PlanetUpdateName", f"'{actor}','{planet}','Planet'", {"planetId": planet, "name": "Planet"}),
            ("guild_moderate_player_name", "PlayerUpdateName", f"'{actor}','{guild}','{target}','Moderated player'", {"playerId": target, "name": "Moderated player"}),
            ("guild_moderate_player_pfp", "PlayerUpdatePfp", f"'{actor}','{guild}','{target}','{picture}'", {"playerId": target, "pfp": picture}),
            ("guild_moderate_player_pfp_cr_attributes", "PlayerUpdatePfpClientRenderAttributes", f"'{actor}','{guild}','{target}','{{}}'", {"playerId": target, "pfpClientRenderAttributes": "{}"}),
            ("guild_moderate_planet_name", "PlanetUpdateName", f"'{actor}','{guild}','{planet}','Moderated planet'", {"planetId": planet, "name": "Moderated planet"}),
            ("guild_moderate_substation_name", "SubstationUpdateName", f"'{actor}','{guild}','{station}','Moderated station'", {"substationId": station, "name": "Moderated station"}),
            ("guild_moderate_substation_pfp", "SubstationUpdatePfp", f"'{actor}','{guild}','{station}','{picture}'", {"substationId": station, "pfp": picture}),
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
