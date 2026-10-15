#!/usr/bin/env python3
"""Persisted registry fake. Run through fake_couch's executable seam, never import.

The registry path is explicit and test-owned. Unknown verbs refuse. Mutation
replays preserve stable identity; failed reply injection may follow publication.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import time


def effective_owner(path, fallback):
    lines = Path(path).read_text().splitlines()
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        return fallback
    fields = dict(line.split(":", 1) for line in lines[1:lines[1:].index("---") + 1] if ":" in line)
    override = fields.get("couch-owner") or (fields.get("owner") if fields.get("type", "").strip() == "session-sync" else None)
    return override.strip().strip("\"'") if override else fallback


def seeded_status():
    """The explicit response override is also a legacy/status fixture seed.

    Only a successful object/null Status can become persisted evidence. Other
    explicit replies still pass through unchanged, without erasing the ledger.
    """
    raw = os.environ.get("FAKE_COUCH_STATUS")
    if not raw:
        return None, False, None
    try:
        envelope = json.loads(raw)
    except (ValueError, TypeError):
        return raw, False, None
    valid = (isinstance(envelope, dict) and envelope.get("Code") == "ok"
             and "Status" in envelope
             and (envelope["Status"] is None or isinstance(envelope["Status"], dict)))
    return raw, valid, envelope["Status"] if valid else None


def publish(state_path, state):
    temporary = state_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_path)


def main():
    args = sys.argv[1:]
    mode = os.environ.get("FAKE_COUCH_REGISTRY_MODE", "")
    if mode == "unsupported":
        print("unknown session-sync verb", file=sys.stderr)
        return 2
    if mode == "malformed":
        print("{not-json")
        return 0
    if mode == "missing":
        print(json.dumps({"Code": "ok", "Error": ""}))
        return 0
    if mode == "delay":
        time.sleep(1)
    state_path = Path(os.environ["FAKE_COUCH_REGISTRY"])
    with open(str(state_path) + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = json.loads(state_path.read_text()) if state_path.exists() else {"paths": {}, "moves": {}}
        ledger = state.setdefault("ledger", {})
        legacy = state.setdefault("legacy", {})
        op = args[1] if len(args) > 1 else ""
        raw_status, valid_seed, seed = seeded_status()
        if op == "status":
            positional = [arg for arg in args[2:] if arg != "--json"]
            if len(positional) != 1 or positional[0].startswith("--") or args[2:].count("--json") != 1:
                print(json.dumps(dict(Code="usage", Error="status requires one path and --json", Status=None)))
                return 1
            path = str(Path(positional[0]).resolve())
            registration = state["paths"].get(path)
            target, key = (ledger, registration["ID"]) if registration else (legacy, path)
            if valid_seed and (key not in target or target[key] != seed):
                target[key] = seed
                publish(state_path, state)
            if raw_status is not None:
                sys.stdout.write(raw_status)
            else:
                print(json.dumps(dict(Code="ok", Error="", Status=target.get(key))))
            return 0
        path = str(Path(args[2]).resolve()) if len(args) > 2 else ""
        changed, registration = False, None
        code, error = "ok", ""
        if op == "lookup":
            registration = state["paths"].get(path)
        elif op == "register":
            owner = args[args.index("--owner") + 1]
            registration = state["paths"].get(path)
            if not Path(path).is_file():
                code, error = "not-registered", "file missing"
            elif registration and registration["RegisteredOwner"] != owner:
                code, error = "owner-conflict", "different fallback owner"
            elif not registration:
                registration = dict(ID=hashlib.sha256(path.encode()).hexdigest(), File=path,
                                    Owner=owner, RegisteredOwner=owner, RegisteredAt="2026-10-15T00:00:00Z")
                state["paths"][path] = registration
                # Import existing legacy evidence once. Registration replay is
                # metadata-only and never resets the owed/write timestamps.
                ledger[registration["ID"]] = legacy.pop(path, seed if valid_seed else None)
                changed = True
        elif op == "rename":
            new = str(Path(args[3]).resolve())
            move = path + "\n" + new
            if move in state["moves"] and state["paths"].get(new, {}).get("ID") == state["moves"][move]:
                registration = state["paths"][new]
            elif new in state["paths"]:
                code, error = "target-conflict", "destination registered"
            elif path not in state["paths"] or not Path(new).is_file():
                code, error = "not-registered", "source registration or destination missing"
            else:
                registration = state["paths"].pop(path)
                registration["File"] = new
                state["paths"][new] = registration
                state["moves"][move] = registration["ID"]
                changed = True
        elif op == "forget":
            forgotten = state["paths"].pop(path, None)
            changed = forgotten is not None
            if forgotten:
                ledger.pop(forgotten["ID"], None)
        else:
            code, error = "usage", "unsupported fake verb"
        if changed:
            publish(state_path, state)
        if registration and Path(registration["File"]).is_file():
            registration = dict(registration, Owner=effective_owner(registration["File"], registration["RegisteredOwner"]))
        if mode == "uncertain" and op != "lookup":
            code, error = "registry-uncertain", "published but reply unavailable"
        if mode == "wrong-path":
            registration = dict(ID="wrong", File="/wrong.md", Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="2026-10-15T00:00:00Z")
        print(json.dumps(dict(Code=code, Error=error, Registration=registration, Changed=changed)))
        return 0 if code == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
