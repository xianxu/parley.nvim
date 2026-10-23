#!/usr/bin/env python3
"""Persisted registry fake. Run through fake_couch's executable seam, never import.

The registry path is explicit and test-owned. Unknown verbs refuse. Mutation
replays preserve stable identity; failed reply injection may follow publication.
"""
import fcntl
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import re
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


def load(state_path):
    state = json.loads(state_path.read_text()) if state_path.exists() else {"paths": {}, "moves": {}}
    state.setdefault("ledger", {})
    state.setdefault("legacy", {})
    return state


def publish(state_path, state):
    temporary = state_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_path)


def instant(stamp):
    """An RFC3339 stamp as an aware datetime, `Z` read as UTC and nanoseconds
    cut to microseconds. A round's `at` is UTC and a submit's `At` carries a
    local offset, so they compare only as instants, never as text (#383)."""
    return datetime.fromisoformat(re.sub(r"(\.\d{6})\d+", r"\1", stamp.replace("Z", "+00:00")))


def keyed(state, path):
    """Where path's ledger entry lives: under its registration, else its path."""
    registration = state["paths"].get(path)
    return (state["ledger"], registration["ID"]) if registration else (state["legacy"], path)


def edit_ledger(state_path, state, args):
    """Test-side ledger edits (#354, #383), never couch verbs:
    `--owe ID MESSAGE` records a `submitted: PATH` send as owed and as the
    file's last submit; `--fold ID PATH` removes an owed send; `--round PATH
    JSON` seeds the file's round sidecar; `--submit-at PATH AT` sets the last
    submit's time."""
    verb = args[0]
    subject = args[1] if verb in ("--round", "--submit-at") else args[2]
    if verb == "--owe":
        if not subject.startswith("submitted: "):
            return 0
        subject = subject[len("submitted: "):]
    target, key = keyed(state, str(Path(subject).resolve()))
    status = target.get(key) or {}
    if verb == "--round":
        state.setdefault("rounds", {})[key] = json.loads(args[2])
    elif verb == "--submit-at":
        status["LastSubmit"] = args[2]
    else:
        owed = [event for event in status.get("Owed") or [] if event.get("ID") != args[1]]
        if verb == "--owe":
            # Microseconds, so a submit right after a round never ties with it.
            now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
            owed.append(dict(ID=args[1], Kind="delivery", At=now))
            status["LastSubmit"] = now
        status["Owed"] = owed
    target[key] = status
    publish(state_path, state)
    return 0


def round_reply(state, args):
    """`round PATH --json` (pair#661): the seeded sidecar, and whether a submit
    came after it."""
    positional = [arg for arg in args[2:] if arg != "--json"]
    if len(positional) != 1 or args[2:].count("--json") != 1:
        return "usage", json.dumps(dict(Code="usage", Error="round answers only as JSON: pass --json"))
    target, key = keyed(state, str(Path(positional[0]).resolve()))
    seeded = state.get("rounds", {}).get(key)
    submit = (target.get(key) or {}).get("LastSubmit")
    cleared = bool(seeded and submit and instant(submit) > instant(seeded["at"]))
    return "ok", json.dumps(dict(Code="ok", Error="", Round=seeded, Cleared=cleared))


def deliver(op, code, reply):
    # FAKE_COUCH_REGISTRY_REPLY_DELAY (seconds): the change is published, and the
    # lock released, before the caller hears about it, as with the real Couch,
    # whose reply travels after it persists (#372). FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS
    # (comma list, default all) limits it, so a spec can watch the registry
    # lead the caller's own view.
    reply_delay = float(os.environ.get("FAKE_COUCH_REGISTRY_REPLY_DELAY") or "0")
    reply_only = os.environ.get("FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS")
    if reply_delay > 0 and (not reply_only or op in reply_only.split(",")):
        time.sleep(min(reply_delay, 10.0))
    print(reply)
    return 0 if code == "ok" else 1


def main():
    args = sys.argv[1:]
    # FAKE_COUCH_REGISTRY_TRACE (a path): one JSON argv per request (#414).
    trace = os.environ.get("FAKE_COUCH_REGISTRY_TRACE")
    if trace:
        with open(trace, "a") as output:
            output.write(json.dumps(args) + "\n")
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
        # FAKE_COUCH_REGISTRY_DELAY (seconds, default 1): a slow registry (#357).
        # FAKE_COUCH_REGISTRY_DELAY_OPS (comma list, default all) slows only those.
        # FAKE_COUCH_REGISTRY_GATE (a path): answer once it exists, the delay
        # being only the upper bound, so a spec decides when Couch answers
        # instead of racing a clock (#414). Its directory going away (the spec's
        # cleanup) opens it too. Each answer it lets through appends a line to
        # PATH.answered, so a spec can tell that nothing was answered yet.
        only = os.environ.get("FAKE_COUCH_REGISTRY_DELAY_OPS")
        if not only or (args[1] if len(args) > 1 else "") in only.split(","):
            delay = float(os.environ.get("FAKE_COUCH_REGISTRY_DELAY") or "1")
            gate = os.environ.get("FAKE_COUCH_REGISTRY_GATE")
            if gate:
                deadline = time.monotonic() + delay
                while (time.monotonic() < deadline and not os.path.exists(gate)
                       and os.path.isdir(os.path.dirname(gate) or ".")):
                    time.sleep(0.02)
                if os.path.isdir(os.path.dirname(gate) or "."):
                    with open(gate + ".answered", "a") as answered:
                        answered.write(("gate" if os.path.exists(gate) else "bound") + "\n")
            else:
                time.sleep(delay)
    state_path = Path(os.environ["FAKE_COUCH_REGISTRY"])
    if len(args) > 1 and args[1] == "round":
        # Read-only: answered under the lock, delivered after it is released.
        with open(str(state_path) + ".lock", "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            code, reply = round_reply(load(state_path), args)
        return deliver("round", code, reply)
    with open(str(state_path) + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = load(state_path)
        ledger, legacy = state["ledger"], state["legacy"]
        if args and args[0] in ("--owe", "--fold", "--round", "--submit-at"):
            return edit_ledger(state_path, state, args)
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
                registration = dict(ID=hashlib.sha256(path.encode()).hexdigest()[:32], File=path,
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
        if registration:
            # Additive namespace projection, not a second persisted authority.
            registration = dict(registration, Namespace=registration.get("Namespace", str(state_path.parent.resolve())))
        if registration and Path(registration["File"]).is_file():
            registration = dict(registration, Owner=effective_owner(registration["File"], registration["RegisteredOwner"]))
        if mode == "uncertain" and op != "lookup":
            code, error = "registry-uncertain", "published but reply unavailable"
        if mode == "wrong-path":
            registration = dict(ID="wrong", File="/wrong.md", Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="2026-10-15T00:00:00Z")
        reply = json.dumps(dict(Code=code, Error=error, Registration=registration, Changed=changed))
    return deliver(op, code, reply)


if __name__ == "__main__":
    sys.exit(main())
