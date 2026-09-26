"""Exercise the local app launcher without starting an interactive editor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class LocalAppTest(unittest.TestCase):
    def test_rejects_a_demo_directory_inside_the_checkout(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            shutil.copy2(REPO / "parley_app", root / "parley_app")
            result = subprocess.run([str(root / "parley_app")], cwd=root,
                                    env=dict(os.environ, PARLEY_DEMO_DIR=str(root / "demo")),
                                    text=True, capture_output=True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("outside the checkout", result.stderr)

    def test_isolates_profile_and_resolves_checkout_from_another_directory(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            checkout = root / "checkout with spaces"
            checkout.mkdir()
            shutil.copy2(REPO / "parley_app", checkout / "parley_app")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            fake = bin_dir / "nvim"
            fake.write_text("#!/usr/bin/env python3\nimport os, sys, json\n"
                            "print(json.dumps({'cwd': os.getcwd(), 'args': sys.argv[1:], "
                            "'env': dict(os.environ)}))\n")
            fake.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                       HOME=str(root / "real home"), XDG_CACHE_HOME=str(root / "cache"))
            env.pop("PARLEY_DEMO_DIR", None)
            command = [str(checkout / "parley_app"), "file with spaces.md"]
            for _ in range(2):
                result = subprocess.run(command, cwd=root, env=env, text=True,
                                        capture_output=True, check=True)
                observed = json.loads(result.stdout)
                demo = root / "cache/parley-app-demo"
                self.assertEqual(str(demo.resolve()), observed["cwd"])
                self.assertEqual(["-u", str(checkout / "packaging/starter-config/init.lua"),
                                  "file with spaces.md"], observed["args"])
                values = observed["env"]
                self.assertEqual(str(checkout), values["PARLEY_RUNTIME"])
                self.assertEqual("parley", values["NVIM_APPNAME"])
                self.assertEqual(str(demo / "home"), values["HOME"])
                for key, leaf in [("CONFIG", "config"), ("DATA", "data"),
                                  ("STATE", "state"), ("CACHE", "cache")]:
                    self.assertEqual(str(demo / leaf), values["XDG_" + key + "_HOME"])
                (demo / "retained").write_text("keep")
            self.assertEqual("keep", (demo / "retained").read_text())


if __name__ == "__main__":
    unittest.main()
