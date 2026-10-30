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
        guild = "0-990940"
        actor = "1-990940"
        target = "1-990943"
        station = "4-990940"
        infusions = ["3-990940-structs1" + "q" * 38, "3-990941-structs1" + "p" * 38]
        cases = [
            ("invite", "GuildMembershipInvite", f"'{actor}','{guild}','{target}','{station}'", target, station, None),
            ("invite_approve", "GuildMembershipInviteApprove", f"'{actor}','{guild}','{target}','{station}'", target, station, None),
            ("invite_deny", "GuildMembershipInviteDeny", f"'{actor}','{guild}','{target}'", target, None, None),
            ("invite_revoke", "GuildMembershipInviteRevoke", f"'{actor}','{guild}','{target}'", target, None, None),
            ("request", "GuildMembershipRequest", f"'{actor}','{guild}','{station}'", actor, station, None),
            ("request_approve", "GuildMembershipRequestApprove", f"'{actor}','{guild}','{target}','{station}'", target, station, None),
            ("request_deny", "GuildMembershipRequestDeny", f"'{actor}','{guild}','{target}'", target, None, None),
            ("request_revoke", "GuildMembershipRequestRevoke", f"'{actor}','{guild}','{target}'", target, None, None),
            ("kick", "GuildMembershipKick", f"'{actor}','{guild}','{target}'", target, None, None),
            ("join", "GuildMembershipJoin", f"'{actor}','{guild}','{station}',ARRAY['{infusions[0]}','{infusions[1]}']::varchar[]", actor, station, infusions),
            ("join", "GuildMembershipJoin", f"'{actor}','{guild}','',ARRAY[]::varchar[]", actor, "", []),
        ]
        checked = []
        for wrapper, message_type, arguments, player, substation, infusion_ids in cases:
            session.query(f"SELECT signer.tx_guild_membership_{wrapper}({arguments});")
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
            expected = {"@type": "/structs.structs.Msg" + message_type, "creator": CREATOR,
                        "guildId": guild, "playerId": player}
            if substation is not None:
                expected["substationId"] = substation
            if infusion_ids is not None:
                expected["infusionId"] = infusion_ids
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
