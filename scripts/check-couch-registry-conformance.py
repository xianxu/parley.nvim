#!/usr/bin/env python3
"""Opt-in offline real/fake Couch registry check through Parley's Lua client.

All files, singleton authority and adopted stores belong to a fresh temporary
root. No live actors, default singleton, network or installed state are used.
The negative control must reject a deliberately wrong-path fake registration.
"""

import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


SCRUB = (
    "COUCH_STORE_DIR", "COUCH_PAIR_DATA_DIR", "COUCH_IDENTITY_DIR", "PAIR_DATA_DIR",
    "XDG_DATA_HOME", "COUCH_TREE", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG",
    "PAIR_SESSION_NAME", "PAIR_LAUNCH_NONCE", "COUCH_CAPTURE_DIR",
    "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_REGISTRY",
)


def run(argv, env):
    return subprocess.run(argv, env=env, text=True, capture_output=True, timeout=30)


def isolated_env(root):
    env = {key: os.environ[key] for key in ("PATH", "LANG", "LC_ALL", "TERM") if key in os.environ}
    for key in SCRUB:
        env[key] = ""
    env["COUCH_ISOLATED_ROOT"] = str(root)
    for key, folder in (
        ("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
        ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state"), ("TMPDIR", "tmp"),
        ("COUCH_STORE_DIR", "store"), ("COUCH_PAIR_DATA_DIR", "pair-data"),
        ("COUCH_IDENTITY_DIR", "identity"),
    ):
        path = root / folder
        path.mkdir()
        env[key] = str(path)
    return env


def adopt_store(binary, env):
    help_result = run([binary, "--help"], env)
    help_text = help_result.stdout + help_result.stderr
    if help_result.returncode or any(marker not in help_text for marker in
                                     ("COUCH_ISOLATED_ROOT", "--adopt-store", "--session-sync register")):
        raise RuntimeError("Couch does not advertise isolated registry diagnostics; refusing store bootstrap")
    args = [binary, "--adopt-store", env["COUCH_STORE_DIR"], "--pair-data",
            env["COUCH_PAIR_DATA_DIR"], "--identity-dir", env["COUCH_IDENTITY_DIR"]]
    preview = run(args, env)
    if preview.returncode:
        raise RuntimeError("isolated adopt-store preview refused: " + preview.stderr + preview.stdout)
    report = json.loads(preview.stdout)
    if report.get("status") == "SELECTED":
        return
    digest = report.get("digest")
    if not isinstance(digest, str) or not digest:
        raise RuntimeError("isolated adopt-store preview omitted digest")
    applied = run([*args, "--apply", digest], env)
    if applied.returncode:
        raise RuntimeError("isolated adopt-store apply refused: " + applied.stderr + applied.stdout)


def probe(nvim, repo, binary, root, *, fake=False, corrupt=False):
    root.mkdir()
    env = isolated_env(root)
    if fake:
        env["FAKE_COUCH_REGISTRY"] = str(root / "registry.json")
        if corrupt:
            env["FAKE_COUCH_REGISTRY_MODE"] = "wrong-path"
    else:
        adopt_store(binary, env)
    fixture = root / "probe.json"
    fixture.write_text(json.dumps({"binary": binary, "root": str(root), "env": env, "fake": fake}))
    env.update(PARLEY_CONFORMANCE_ROOT=str(repo), PARLEY_REGISTRY_PROBE=str(fixture))
    return run([nvim, "--headless", "-n", "-u", "NONE", "-l",
                str(repo / "scripts/couch-registry-probe.lua")], env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--couch", default=os.environ.get("COUCH_CONFORMANCE_BINARY", "couch"),
                        help="Couch executable supporting COUCH_ISOLATED_ROOT and public adopt-store")
    parser.add_argument("--fake-only", action="store_true", help="exercise probe and negative control without real Couch")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    nvim, binary = shutil.which("nvim"), shutil.which(args.couch)
    if not nvim or (not args.fake_only and not binary):
        parser.error("nvim and an explicitly isolated-capable Couch executable are required")
    if binary:
        binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="parley-registry-conformance-", dir=os.environ.get("TMPDIR") or "/tmp") as name:
        scratch = Path(name).resolve()
        tempbin = scratch / "bin"
        tempbin.mkdir()
        fake = tempbin / "couch"
        fake.write_text("#!/bin/sh\nexec " + shlex.quote(sys.executable) + " "
                        + shlex.quote(str(repo / "tests/fixtures/fake_couch_registry.py")) + ' "$@"\n')
        fake.chmod(0o700)
        for label, command, is_fake in ([('fake', str(fake), True)] if args.fake_only else
                                        [('real', binary, False), ('fake', str(fake), True)]):
            result = probe(nvim, repo, command, scratch / label, fake=is_fake)
            if result.returncode:
                raise RuntimeError(label + " production probe failed:\n" + result.stdout + result.stderr)
            print(label + ": " + (result.stdout + result.stderr).strip())
        negative = probe(nvim, repo, str(fake), scratch / "corrupt-fake", fake=True, corrupt=True)
        if negative.returncode == 0:
            raise RuntimeError("negative control failed: corrupted fake was accepted")
        if "expected registered, got" not in negative.stderr + negative.stdout:
            raise RuntimeError("negative control failed for an unrelated reason:\n" + negative.stdout + negative.stderr)
        print("PASS: deliberately corrupted fake rejected by production-client probe")
        print("All fixture, singleton and adopted-store paths were temporary and have been removed on exit.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
