#!/usr/bin/env python3
"""Opt-in offline real/fake Couch registry check through Parley's Lua client.

All files, singleton authority and adopted stores belong to a fresh temporary
root. No live actors, default singleton, network or installed state are used.
The negative control must reject a deliberately wrong-path fake registration.
"""

import argparse
import asyncio
import json
import os
import signal
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
    "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_REGISTRY", "FAKE_COUCH_EDITOR_MODE",
)


def run(argv, env, *, child_tree=False):
    if not child_tree:
        return subprocess.run(argv, env=env, text=True, capture_output=True, timeout=30)
    # Embedded editors inherit this disposable group. Timeout ends the whole
    # probe tree when Lua cleanup could not run.
    with subprocess.Popen(argv, env=env, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, start_new_session=True) as child:
        try:
            stdout, stderr = child.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
            child.communicate()
            raise
        return subprocess.CompletedProcess(argv, child.returncode, stdout, stderr)


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


def probe(nvim, repo, binary, root, *, fake=False, corrupt=False, editor_endpoints=False):
    root.mkdir()
    env = isolated_env(root)
    if fake:
        env["FAKE_COUCH_REGISTRY"] = str(root / "registry.json")
        if corrupt:
            env["FAKE_COUCH_EDITOR_MODE" if editor_endpoints else "FAKE_COUCH_REGISTRY_MODE"] = (
                "wrong-identity" if editor_endpoints else "wrong-path")
    else:
        adopt_store(binary, env)
    # The admission seam intentionally invokes `couch`, just as the editor
    # does. Select the candidate inside this process's disposable PATH only.
    command_dir = root / "bin"
    command_dir.mkdir()
    (command_dir / "couch").symlink_to(binary)
    env["PATH"] = str(command_dir) + os.pathsep + env.get("PATH", "")
    fixture = root / "probe.json"
    config = {"binary": binary, "root": str(root), "env": env, "fake": fake}
    env.update(PARLEY_CONFORMANCE_ROOT=str(repo), PARLEY_REGISTRY_PROBE=str(fixture))
    if editor_endpoints:
        # Explicit owned 0700 test runtime; no operator runtime or public
        # listener fallback. Short scratch paths satisfy Unix address bounds.
        scratch_base = "/Volumes/TestScratch" if Path("/Volumes/TestScratch").is_dir() else (os.environ.get("TMPDIR") or "/tmp")
        with tempfile.TemporaryDirectory(prefix="pe-", dir=scratch_base) as runtime:
            config["runtime_parent"] = str(Path(runtime).resolve() / "rpc")
            fixture.write_text(json.dumps(config))
            return run([nvim, "--headless", "-n", "-u", "NONE", "-l",
                        str(repo / "scripts/couch-editor-probe.lua")], env, child_tree=True)
    fixture.write_text(json.dumps(config))
    return run([nvim, "--headless", "-n", "-u", "NONE", "-l",
                str(repo / "scripts/couch-registry-probe.lua")], env)


async def editor_bridge_probe(bridge, repo, root, *, binary=None, launch_env=None, session_factory=None):
    """Use the shared producer owner; this driver owns only its native probe."""
    if session_factory is None:
        from couch_bridge import BridgeSession
        session_factory = BridgeSession
    root.mkdir(parents=True, exist_ok=True)
    # Unix sockets need short physical parents even under a long TMPDIR.
    base = Path("/tmp").resolve()  # native wrapper sockets need the shortest system parent
    producer_parent = Path(tempfile.mkdtemp(prefix="cb-", dir=base)).resolve()
    runtime_parent = Path(tempfile.mkdtemp(prefix="pe-", dir=base)).resolve()
    witnesses = {path: path.stat() for path in (producer_parent, runtime_parent)}
    argv = [str(bridge), "--scratch-parent", str(producer_parent)]
    if binary:
        argv += ["--couch", str(binary)]
    session = session_factory(argv, env=dict(os.environ if launch_env is None else launch_env),
                              startup_s=300, lifetime_s=600, stop_s=15, margin_s=15)
    try:
        async with session:
            ready = session.readiness
            environment = dict(ready["Environment"])
            candidate = shutil.which("couch", path=environment["PATH"])
            nvim = shutil.which("nvim", path=environment["PATH"])
            if not candidate or not nvim:
                raise RuntimeError("bridge private PATH omitted couch or nvim")
            fixture = runtime_parent / "probe.json"
            fixture.write_text(json.dumps({"binary": candidate, "root": str(root), "env": environment,
                "fake": False, "namespace": ready["Namespace"], "documents": ready["Documents"],
                "runtime_parent": str(runtime_parent / "rpc")}))
            probe_env = dict(environment, PARLEY_CONFORMANCE_ROOT=str(repo), PARLEY_REGISTRY_PROBE=str(fixture))
            result = await session.run([nvim, "--headless", "-n", "-u", "NONE", "-l",
                str(repo / "scripts/couch-editor-probe.lua")], env=probe_env, cwd=str(repo), timeout=120)
            if result.returncode:
                raise RuntimeError("native editor probe failed:\n" + result.stdout + result.stderr)
        if not session.cleaned:
            raise RuntimeError("bridge cleanup unconfirmed")
        for path, witness in witnesses.items():
            current = path.lstat()
            if (current.st_dev, current.st_ino, current.st_uid, current.st_mode) != (
                    witness.st_dev, witness.st_ino, witness.st_uid, witness.st_mode):
                raise RuntimeError("consumer scratch parent replaced: " + str(path))
        # The shared bridge must have removed its own root. Never recurse into it.
        producer_parent.rmdir()
        shutil.rmtree(runtime_parent)  # native probe succeeded and joined its editors
        return result
    except BaseException as error:
        retained = "retained consumer evidence: " + str(producer_parent) + "; " + str(runtime_parent)
        if isinstance(error, Exception):
            raise RuntimeError(str(error) + "; " + retained) from error
        print(retained, file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--couch", default=os.environ.get("COUCH_CONFORMANCE_BINARY"),
                        help="Couch executable supporting COUCH_ISOLATED_ROOT and public adopt-store")
    parser.add_argument("--bridge", help="absolute supported couch-conformance-bridge executable for real editor endpoints")
    parser.add_argument("--fake-only", action="store_true", help="exercise probe and negative control without real Couch")
    parser.add_argument("--editor-endpoints", action="store_true",
                        help="check endpoint handshake, retry, takeover and retirement in native editors")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    nvim = shutil.which("nvim")
    binary = shutil.which(args.couch or "couch")
    if args.editor_endpoints and not args.fake_only and not args.bridge:
        parser.error("real editor endpoint conformance requires --bridge ABS")
    if args.bridge and (not Path(args.bridge).is_absolute() or not os.access(args.bridge, os.X_OK)):
        parser.error("--bridge must name an absolute executable")
    if not nvim or (not args.fake_only and not args.editor_endpoints and not binary):
        parser.error("nvim and an explicitly isolated-capable Couch executable are required")
    if binary:
        binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="parley-registry-conformance-", dir=os.environ.get("TMPDIR") or "/tmp") as name:
        scratch = Path(name).resolve()
        tempbin = scratch / "bin"
        tempbin.mkdir()
        fake = tempbin / "couch"
        fake.write_text('#!/bin/sh\nif [ "$1" = "--editor-endpoint" ]; then exec '
                        + shlex.quote(sys.executable) + " "
                        + shlex.quote(str(repo / "tests/fixtures/fake_couch_editor.py")) + ' "$@"; fi\n'
                        + 'case "$2" in\noperator-acquire|operator-release) exec '
                        + shlex.quote(sys.executable) + " "
                        + shlex.quote(str(repo / "tests/fixtures/fake_couch_operator.py")) + ' "$@" ;;\n'
                        + '*) exec ' + shlex.quote(sys.executable) + " "
                        + shlex.quote(str(repo / "tests/fixtures/fake_couch_registry.py")) + ' "$@" ;;\nesac\n')
        fake.chmod(0o700)
        if args.editor_endpoints and not args.fake_only:
            candidate = binary if args.couch else None
            if args.couch and not candidate:
                parser.error("explicit --couch executable not found")
            result = asyncio.run(editor_bridge_probe(args.bridge, repo, scratch / "real", binary=candidate))
            print("real: " + (result.stdout + result.stderr).strip())
        cases = [('fake', str(fake), True)] if args.fake_only or args.editor_endpoints else [
            ('real', binary, False), ('fake', str(fake), True)]
        for label, command, is_fake in cases:
            result = probe(nvim, repo, command, scratch / label, fake=is_fake,
                           editor_endpoints=args.editor_endpoints)
            if result.returncode:
                raise RuntimeError(label + " production probe failed:\n" + result.stdout + result.stderr)
            print(label + ": " + (result.stdout + result.stderr).strip())
        negative = probe(nvim, repo, str(fake), scratch / "corrupt-fake", fake=True, corrupt=True,
                         editor_endpoints=args.editor_endpoints)
        if negative.returncode == 0:
            raise RuntimeError("negative control failed: corrupted fake was accepted")
        expected = "expected confirmed, got" if args.editor_endpoints else "expected registered, got"
        if expected not in negative.stderr + negative.stdout:
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
