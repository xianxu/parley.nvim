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
        op = args[1] if len(args) > 1 else ""
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
                changed = True
            if registration:
                lines = Path(path).read_text().splitlines()
                if lines and lines[0] == "---" and "---" in lines[1:]:
                    fields = dict(line.split(":", 1) for line in lines[1:lines[1:].index("---")+1] if ":" in line)
                    override = fields.get("couch-owner") or (fields.get("owner") if fields.get("type", "").strip() == "session-sync" else None)
                    registration["Owner"] = override.strip().strip("\"'") if override else owner
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
            changed = state["paths"].pop(path, None) is not None
        else:
            code, error = "usage", "unsupported fake verb"
        if changed:
            temporary = state_path.with_suffix(".tmp")
            temporary.write_text(json.dumps(state))
            temporary.replace(state_path)
        if mode == "uncertain" and op != "lookup":
            code, error = "registry-uncertain", "published but reply unavailable"
        if mode == "wrong-path":
            registration = dict(ID="wrong", File="/wrong.md", Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="2026-10-15T00:00:00Z")
        print(json.dumps(dict(Code=code, Error=error, Registration=registration, Changed=changed)))
        return 0 if code == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
