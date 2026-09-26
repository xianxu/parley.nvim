"""Exercise the local app launcher without starting an interactive editor."""
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class LocalAppTest(unittest.TestCase):
    def test_production_starter_stays_non_repo_for_marked_demo_ancestry(self):
        real_nvim = shutil.which("nvim")
        self.assertIsNotNone(real_nvim)
        for alternate in (False, True):
            for marker in ("none", "demo", "ancestor"):
                with self.subTest(alternate=alternate, marker=marker), tempfile.TemporaryDirectory() as scratch:
                    root = Path(scratch).resolve()
                    demo = root / ("alternate" if alternate else "cache/parley-app-demo")
                    demo.mkdir(parents=True)
                    (demo / ".parley-app-demo").write_text("parley_app v1\n")
                    if marker != "none":
                        (demo if marker == "demo" else root).joinpath(".parley").write_text("")
                    probe = root / "probe.lua"
                    probe.write_text('''
vim.opt.runtimepath:prepend(vim.env.PARLEY_RUNTIME)
package.loaded['parley.starter_onboarding'] = { start = function() end }
require('parley.starter').start()
local p = require('parley')
assert(not p.config.repo_root, 'demo entered repo mode')
assert(vim.fs.normalize(p.config.chat_dir) == vim.fn.stdpath('data') .. '/chats')
vim.cmd('qa!')
''')
                    bin_dir = root / "bin"
                    bin_dir.mkdir()
                    fake = bin_dir / "nvim"
                    fake.write_text("#!/bin/sh\nexec " + shlex.quote(real_nvim)
                                    + " --headless -u NONE -i NONE -l " + shlex.quote(str(probe)) + "\n")
                    fake.chmod(0o755)
                    env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                               XDG_CACHE_HOME=str(root / "cache"), PARLEY_TEST_MODE="1")
                    env.pop("PARLEY_DEMO_DIR", None)
                    env.pop("PARLEY_CHAT_DIR", None)
                    env.pop("PARLEY_REPO_MODE", None)
                    if alternate:
                        env["PARLEY_DEMO_DIR"] = str(demo)
                    result = subprocess.run([str(REPO / "parley_app")], env=env,
                                            text=True, capture_output=True, timeout=20)
                    self.assertEqual(0, result.returncode, result.stderr)

    def test_nuke_deletes_only_owned_demo_and_next_launch_is_fresh(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            demo = root / "demo"
            bin_dir = root / "bin"
            bin_dir.mkdir()
            fake = bin_dir / "nvim"
            fake.write_text("#!/bin/sh\nprintf launched\n")
            fake.chmod(0o755)
            env = dict(os.environ, PARLEY_DEMO_DIR=str(demo),
                       PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
            command = [str(REPO / "parley_app")]
            normal = root / "normal-profile"
            normal.mkdir()
            (normal / "keep").write_text("keep")
            subprocess.run(command + ["--tutorials"], env=env, check=True, capture_output=True)
            for folder in ("home", "config", "data", "state", "cache"):
                (demo / folder).mkdir(exist_ok=True)
                (demo / folder / "cached").write_text("old")
            (demo / "external-link").symlink_to(normal, target_is_directory=True)
            for _ in range(2):
                result = subprocess.run(command + ["--nuke"], env=env, text=True, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertNotIn("launched", result.stdout)
                self.assertFalse(demo.exists())
                self.assertEqual("keep", (normal / "keep").read_text())
            subprocess.run(command, env=env, check=True, capture_output=True)
            self.assertTrue((demo / "home").is_dir())
            self.assertFalse((demo / "data/cached").exists())

    def test_nuke_refuses_unowned_or_live_demo(self):
        with tempfile.TemporaryDirectory() as scratch:
            demo = Path(scratch) / "demo"
            demo.mkdir()
            (demo / "precious").write_text("keep")
            env = dict(os.environ, PARLEY_DEMO_DIR=str(demo))
            command = [str(REPO / "parley_app"), "--nuke"]
            result = subprocess.run(command, env=env, text=True, capture_output=True)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual("keep", (demo / "precious").read_text())
            (demo / ".parley-app-demo").write_text("parley_app v1\n")
            (demo / ".nvim-pid").write_text(str(os.getpid()))
            result = subprocess.run(command, env=env, text=True, capture_output=True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("running", result.stderr)
            self.assertTrue((demo / "precious").exists())

    def test_nuke_refuses_symlink_root_and_checkout_ancestor(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            checkout = root / "checkout"
            checkout.mkdir()
            shutil.copy2(REPO / "parley_app", checkout / "parley_app")
            (root / ".parley-app-demo").write_text("parley_app v1\n")
            link = root / "link"
            link.symlink_to(root, target_is_directory=True)
            for demo in (root, link):
                result = subprocess.run([str(checkout / "parley_app"), "--nuke"],
                                        env=dict(os.environ, PARLEY_DEMO_DIR=str(demo)),
                                        text=True, capture_output=True)
                self.assertNotEqual(0, result.returncode)
                self.assertTrue((checkout / "parley_app").exists())

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
            result = subprocess.run([str(checkout / "parley_app"), "--tutorials"],
                                    cwd=root, env=env, text=True, capture_output=True, check=True)
            observed = json.loads(result.stdout)
            self.assertEqual(["-u", str(checkout / "packaging/starter-config/init.lua")], observed["args"])
            self.assertEqual(str(checkout / "packaging/tutorials"), observed["env"]["PARLEY_CHAT_DIR"])


if __name__ == "__main__":
    unittest.main()
