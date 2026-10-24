"""Stateful editor-endpoint CLI fake, invoked by fake_couch.lua via python3.

Registry and endpoint mutations share one flock and retain unknown state keys.
This exercises the transport boundary, not native endpoint/process conformance.
FAKE_COUCH_EDITOR_MODE injects malformed/missing/unsupported/wrong-identity/
oversized/uncertain/delay replies. Delay uses one process, never a shell child.
"""
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

sys.dont_write_bytecode = True
from fake_couch_registry import load, publish


REGISTER_FIELDS = {"Version", "Namespace", "DocumentID", "EditorIncarnation", "AttachID", "PID", "Socket", "Buffer", "Mode"}
UNREGISTER_FIELDS = {"Version", "Namespace", "EditorIncarnation", "PID", "Entries", "ProcessIdentity"}
ENTRY_FIELDS = {"DocumentID", "AttachID", "BindingGeneration"}
MAX_ATTACH_ID = 18446744073709551615


def positive(value):
    return type(value) is int and value > 0


def hex_id(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{32}", value) is not None


def absolute(value):
    return isinstance(value, str) and value.startswith("/") and "\0" not in value and os.path.normpath(value) == value


def attach(value):
    return isinstance(value, str) and re.fullmatch(r"[1-9][0-9]*", value) is not None and len(value) <= 20 and int(value) <= MAX_ATTACH_ID


def object_pairs(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate request key")
        value[key] = item
    return value


def read_request(operation, args):
    if operation == "lookup":
        if len(args) != 7 or args[2] != "--namespace" or args[4] != "--document-id" or args[6] != "--json":
            raise ValueError("lookup requires namespace, document-id and --json")
        request = dict(Namespace=args[3], DocumentID=args[5])
        if not absolute(request["Namespace"]) or not hex_id(request["DocumentID"]):
            raise ValueError("invalid lookup identity")
        return request
    if operation not in ("register", "unregister") or args[2:] != ["--json"]:
        raise ValueError("unsupported editor endpoint command")
    limit = 8192 if operation == "register" else 262144
    raw = sys.stdin.buffer.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("request too large")
    request = json.loads(raw, object_pairs_hook=object_pairs)
    if not isinstance(request, dict) or type(request.get("Version")) is not int or request["Version"] != 1:
        raise ValueError("invalid request version")
    if not absolute(request.get("Namespace")) or not hex_id(request.get("EditorIncarnation")) or not positive(request.get("PID")):
        raise ValueError("invalid namespace or process")
    if operation == "register":
        if set(request) != REGISTER_FIELDS or not hex_id(request.get("DocumentID")) or not attach(request.get("AttachID")):
            raise ValueError("invalid register fields")
        if not absolute(request.get("Socket")) or not positive(request.get("Buffer")) or request.get("Mode") not in ("desktop", "headless"):
            raise ValueError("invalid endpoint")
    else:
        required = UNREGISTER_FIELDS - {"ProcessIdentity"}
        if not required <= set(request) or set(request) - UNREGISTER_FIELDS:
            raise ValueError("invalid unregister fields")
        if "ProcessIdentity" in request and (not isinstance(request["ProcessIdentity"], str) or not request["ProcessIdentity"]):
            raise ValueError("invalid process identity")
        entries = request.get("Entries")
        if not isinstance(entries, list) or not 1 <= len(entries) <= 256:
            raise ValueError("invalid unregister batch")
        documents = set()
        for entry in entries:
            if not isinstance(entry, dict) or set(entry) != ENTRY_FIELDS or not hex_id(entry.get("DocumentID")) or not attach(entry.get("AttachID")) or not hex_id(entry.get("BindingGeneration")):
                raise ValueError("invalid unregister entry")
            if entry["DocumentID"] in documents:
                raise ValueError("duplicate unregister document")
            documents.add(entry["DocumentID"])
    return request


def key(*parts):
    return "\n".join(parts)


def envelope(code="ok", error="", **extra):
    return dict(Version=1, Code=code, Error=error, EditorEndpoint=None, **extra)


def registration(state, request, state_path):
    for path, value in state.get("paths", {}).items():
        namespace = value.get("Namespace", str(state_path.parent.resolve()))
        if value.get("ID") == request["DocumentID"] and namespace == request["Namespace"]:
            file = Path(value.get("File", path)).resolve()
            return str(file) if file.is_file() else None
    return None


def transition(state, operation, request, state_path):
    endpoints = state.setdefault("editor_endpoints", {})
    current = endpoints.setdefault("current", {})
    evidence = endpoints.setdefault("evidence", {})
    namespace = request["Namespace"]
    if operation == "lookup":
        result = envelope()
        result["EditorEndpoint"] = current.get(key(namespace, request["DocumentID"]))
        return result, 0, False
    if operation == "unregister":
        results, changed = [], False
        for entry in request["Entries"]:
            document_key = key(namespace, entry["DocumentID"])
            binding = current.get(document_key)
            known = any(row["binding"]["Namespace"] == namespace and row["binding"]["DocumentID"] == entry["DocumentID"] for row in evidence.values())
            status = "stale" if known else "absent"
            if binding and all(binding[field] == request[field] for field in ("Namespace", "EditorIncarnation", "PID")) and all(binding[field] == entry[field] for field in ENTRY_FIELDS) and ("ProcessIdentity" not in request or request["ProcessIdentity"] == binding["ProcessIdentity"]):
                del current[document_key]
                owner_key = key(namespace, binding["EditorIncarnation"], entry["DocumentID"])
                if owner_key in evidence:
                    evidence[owner_key]["status"] = "retired"
                status, changed = "removed", True
            results.append(dict(entry, Status=status))
        return envelope(Results=results), 0, changed
    file = registration(state, request, state_path)
    if file is None:
        return envelope("not-registered", "document is not registered"), 4, False
    document_key = key(namespace, request["DocumentID"])
    owner_key = key(namespace, request["EditorIncarnation"], request["DocumentID"])
    previous = evidence.get(owner_key)
    active = current.get(document_key)
    for row in evidence.values():
        binding = row["binding"]
        if binding["Namespace"] == namespace and binding["EditorIncarnation"] == request["EditorIncarnation"] and binding["PID"] != request["PID"]:
            return envelope("conflict", "incarnation belongs to another process"), 4, False
    if previous and int(request["AttachID"]) <= int(previous["binding"]["AttachID"]):
        if request["AttachID"] != previous["binding"]["AttachID"]:
            return envelope("stale", "attachment is below high water"), 4, False
        if previous["status"] != "current":
            return envelope("superseded", "attachment is retired or superseded"), 4, False
        binding = previous["binding"]
        if any(binding[field] != request[field] for field in REGISTER_FIELDS - {"Version"}) or binding["File"] != file:
            return envelope("conflict", "same attachment has different payload"), 4, False
        result = envelope(Changed=False)
        result["EditorEndpoint"] = binding
        return result, 0, False
    if owner_key not in evidence and len(evidence) >= 4096:
        return envelope("unavailable", "retained evidence capacity"), 3, False
    blocked = active and active["Mode"] == "desktop" and request["Mode"] == "headless"
    count = sum(binding["EditorIncarnation"] == request["EditorIncarnation"] and binding["Namespace"] == namespace for binding in current.values())
    replacing_own = active and active["EditorIncarnation"] == request["EditorIncarnation"]
    if not blocked and count >= 256 and not replacing_own:
        return envelope("unavailable", "active endpoint capacity"), 3, False
    binding = {field: value for field, value in request.items() if field != "Version"}
    binding.update(ProcessIdentity="fake-native:" + str(request["PID"]) + ":" + request["EditorIncarnation"], BindingGeneration=uuid.uuid4().hex, File=file)
    evidence[owner_key] = dict(binding=binding, status="retired" if blocked else "current")
    if blocked:
        return envelope("desktop-active", "a desktop editor is current"), 4, True
    if active:
        displaced = evidence.get(key(namespace, active["EditorIncarnation"], active["DocumentID"]))
        if displaced and displaced["binding"]["AttachID"] == active["AttachID"]:
            displaced["status"] = "superseded"
    # Replacing the same pair must leave its new high-water row current.
    evidence[owner_key]["status"] = "current"
    current[document_key] = binding
    result = envelope(Changed=True)
    result["EditorEndpoint"] = binding
    return result, 0, True


def atomic_write(path, text):
    # A spec polls for these files and then reads them: it must see the whole
    # content or no file, never an empty file between create and write (#421).
    temporary = "%s.%d.tmp" % (path, os.getpid())  # concurrent children never share one
    Path(temporary).write_text(text)
    os.replace(temporary, path)


def main():
    args = sys.argv[1:]
    state_path = Path(os.environ["FAKE_COUCH_REGISTRY"])
    atomic_write(str(state_path) + ".editor-argv", "\n".join(args) + "\n")
    atomic_write(str(state_path) + ".editor-pid", str(os.getpid()) + "\n")
    with open(str(state_path) + ".editor-launches", "a") as launches:
        launches.write((args[1] if len(args) > 1 else "invalid") + "\n")
    mode = os.environ.get("FAKE_COUCH_EDITOR_MODE", "")
    if mode == "delay":
        time.sleep(float(os.environ.get("FAKE_COUCH_EDITOR_DELAY") or "1"))
    if mode == "unsupported":
        print("unknown editor-endpoint verb", file=sys.stderr)
        return 2
    try:
        operation = args[1] if len(args) > 1 else ""
        request = read_request(operation, args)
    except (ValueError, KeyError, TypeError):
        print(json.dumps(envelope("invalid", "invalid endpoint request")))
        return 2
    with open(str(state_path) + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = load(state_path)
        result, code, changed = transition(state, operation, request, state_path)
        if changed:
            publish(state_path, state)
    # Publication precedes acknowledgment. The test releases this exact gate;
    # cancellation/deadline joins this same process if a gate stays closed.
    gate = os.environ.get("FAKE_COUCH_EDITOR_REPLY_GATE")
    if operation == "register" and gate:
        # PATH.held: published, acknowledgment held, so a spec can expire a
        # deadline in exactly that phase instead of racing startup (#421).
        atomic_write(gate + ".held", str(os.getpid()) + "\n")
        while not Path(gate).exists():
            time.sleep(0.01)
    if mode == "uncertain" and operation != "lookup":
        result, code = envelope("uncertain", "published but reply unavailable"), 5
    elif mode == "malformed":
        print("{not-json")
        return 0
    elif mode == "missing":
        result = dict(Version=1, Code="ok", Error="")
    elif mode == "wrong-identity" and result.get("EditorEndpoint"):
        result["EditorEndpoint"] = dict(result["EditorEndpoint"], DocumentID=("1" if result["EditorEndpoint"]["DocumentID"] == "0" * 32 else "0") * 32)
    elif mode == "oversized":
        result["Future"] = "x" * 1048576
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main())
