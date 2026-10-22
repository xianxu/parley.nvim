"""Consumer orchestration tests; the bridge double owns its two fixtures."""
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("registry_driver", REPO / "scripts/check-couch-registry-conformance.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class BridgeConsumerTest(unittest.TestCase):
    def setUp(self):
        base = "/Volumes/TestScratch" if Path("/Volumes/TestScratch").is_dir() else os.environ.get("TMPDIR", "/tmp")
        self.root = Path(tempfile.mkdtemp(prefix="parley-bridge-driver-", dir=base))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("couch", "nvim"):
            (self.bin / name).symlink_to("/usr/bin/true")
        self.documents = [{"ID": "a" * 32, "File": str(self.root / "first.md")},
                          {"ID": "b" * 32, "File": str(self.root / "first.side/second.md")}]
        self.environment = {"PATH": str(self.bin), "HOME": str(self.root / "home"),
                            "COUCH_ISOLATED_ROOT": str(self.root), "COUCH_STORE_DIR": str(self.root / "store")}
        self.ready = {"Version": 1, "Namespace": str(self.root / "store"),
                      "Socket": str(self.root / "socket"), "Environment": self.environment,
                      "Documents": self.documents}
        self.calls = []
        self.instances = []

    def tearDown(self):
        for instance in self.instances:
            for key in ("bridge_parent", "runtime_parent"):
                path = getattr(instance, key, None)
                if path and Path(path).exists():
                    shutil.rmtree(path)  # stateful double started no native processes
        shutil.rmtree(self.root)

    def factory(self, failure=None):
        owner = self
        class Session:
            def __init__(self, argv, env, **limits):
                self.argv, self.env, self.limits = argv, env, limits
                self.bridge_parent = argv[argv.index("--scratch-parent") + 1]
                self.readiness, self.cleaned = owner.ready, False
                owner.instances.append(self)
            async def __aenter__(self):
                owner.calls.append("ready")
                return self
            async def run(self, argv, *, env, cwd=None, timeout=30):
                self.native_argv, self.native_env = argv, env
                self.config = json.loads(Path(env["PARLEY_REGISTRY_PROBE"]).read_text())
                self.runtime_parent = str(Path(self.config["runtime_parent"]).parent)
                owner.calls.append("probe")
                if failure == "probe":
                    raise RuntimeError("native probe failed")
                return subprocess.CompletedProcess(argv, 0, "PASS native parent and side doc", "")
            async def __aexit__(self, *args):
                owner.calls.append("stop")
                if failure == "stop":
                    raise RuntimeError("producer cleanup uncertain")
                self.cleaned = True
        return Session

    def execute(self, failure=None):
        return asyncio.run(driver.editor_bridge_probe("/candidate/bridge", REPO, self.root,
            binary="/candidate/couch", launch_env={"PATH": "/native/tools", "UNRELATED_SECRET": "must-not-leak"},
            session_factory=self.factory(failure)))

    def test_replaces_environment_uses_supplied_ids_and_stops_before_removal(self):
        result = self.execute()
        instance = self.instances[0]
        self.assertEqual(0, result.returncode)
        self.assertEqual(["ready", "probe", "stop"], self.calls)
        self.assertEqual(self.environment, instance.config["env"])
        self.assertEqual(self.documents, instance.config["documents"])
        self.assertEqual(self.ready["Namespace"], instance.config["namespace"])
        self.assertNotIn("UNRELATED_SECRET", instance.native_env)
        self.assertEqual(str(self.bin / "nvim"), instance.native_argv[0])
        self.assertEqual(str(self.bin / "couch"), instance.config["binary"])
        self.assertEqual(["/candidate/bridge", "--scratch-parent", instance.bridge_parent,
                          "--couch", "/candidate/couch"], instance.argv)
        self.assertFalse(Path(instance.bridge_parent).exists())
        self.assertFalse(Path(instance.runtime_parent).exists())

    def test_joined_native_probe_never_signals_a_retired_process_group(self):
        with patch.object(driver.os, "killpg") as signal_group:
            result = driver.run(["/usr/bin/true"], dict(os.environ), child_tree=True)
        self.assertEqual(0, result.returncode)
        signal_group.assert_not_called()

    def test_probe_failure_stops_bridge_but_retains_uncertain_native_artifacts(self):
        with self.assertRaisesRegex(RuntimeError, "retained"):
            self.execute("probe")
        self.assertEqual(["ready", "probe", "stop"], self.calls)
        self.assertTrue(Path(self.instances[0].runtime_parent).exists())

    def test_unknown_producer_cleanup_retains_the_bridge_parent(self):
        with self.assertRaisesRegex(RuntimeError, "retained"):
            self.execute("stop")
        self.assertTrue(Path(self.instances[0].bridge_parent).exists())


if __name__ == "__main__":
    unittest.main()
