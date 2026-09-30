"""Exercise the local app launcher without starting an interactive editor."""
import json
import fcntl
from datetime import date
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
FAKE_BUNDLE = "bundle-" + "a" * 64


class LocalAppTest(unittest.TestCase):
    def setUp(self):
        # Replace only the artifact runner boundary. Every other Python call
        # (including fake editors) uses the real interpreter unchanged.
        fixture = tempfile.TemporaryDirectory()
        self.addCleanup(fixture.cleanup)
        binaries = Path(fixture.name)
        wrapper = binaries / 'python3'
        wrapper.write_text('#!' + sys.executable + '\n' + '''
import json, os, pathlib, subprocess, sys, time
if len(sys.argv) < 2 or not sys.argv[1].endswith('/scripts/editor-dependencies.py'):
    os.execv(REAL_PYTHON, [REAL_PYTHON] + sys.argv[1:])
args = sys.argv[2:]
if args[:2] == ['repair', '--root']:
    command = [REAL_PYTHON, REAL_RUNNER, '--lock-timeout', '.1'] + args
    if os.environ.get('RACE_REPAIR_ROOT'):
        result = subprocess.run(command)
        if result.returncode:
            sys.exit(result.returncode)
        barrier = pathlib.Path(os.environ['RACE_REPAIR_ROOT'])
        (barrier / 'repaired').touch()
        while not (barrier / 'resume').exists(): time.sleep(.01)
        sys.exit(0)
    os.execv(REAL_PYTHON, command)
assert args[0] == '--runtime' and args[1] == os.environ['PARLEY_RUNTIME']
assert args[2] == '--profile' and args[3] in ('app', 'recording')
assert args[4:6] == ['run', '--root'] and args[7] == '--'
assert args[3] == os.environ['PARLEY_EDITOR_PROFILE']
root = pathlib.Path(args[6])
root.mkdir(parents=True, exist_ok=True)
(root / '.parley-editor-owned').write_text('parley-editor-bundles-v1\\n')
(root / '.lock').touch()
(root.parent / 'bundle-request.json').write_text(json.dumps({'runtime': args[1], 'profile': args[3],
    'root': str(root), 'command': args[8:], 'pid': os.getpid()}))
if (root.parent / 'bundle-reject').exists():
    print('fixture bundle verification failed', file=sys.stderr)
    sys.exit(23)
bundle = root / FAKE_BUNDLE
if not bundle.exists():
    bundle.mkdir()
    (bundle / 'artifact').write_text('pinned dependency')
    count = root.parent / 'bundle-downloads'
    count.write_text(str(int(count.read_text()) + 1 if count.exists() else 1))
os.environ['PARLEY_EDITOR_BUNDLE'] = str(bundle)
os.execvp(args[8], args[8:])
'''.replace('REAL_PYTHON', repr(sys.executable))
            .replace('REAL_RUNNER', repr(str(REPO / 'scripts/editor-dependencies.py')))
            .replace('FAKE_BUNDLE', repr(FAKE_BUNDLE)))
        wrapper.chmod(0o755)
        environment = patch.dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'])
        environment.start()
        self.addCleanup(environment.stop)

    def test_routes_app_and_recording_through_bundle_verification_before_exec(self):
        for recording in (False, True):
            with self.subTest(recording=recording), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                checkout = root / 'checkout'
                checkout.mkdir()
                shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
                binaries = root / 'bin'
                binaries.mkdir()
                editor = binaries / 'nvim'
                editor.write_text('#!/usr/bin/env python3\nimport json, os\n'
                                  'print(json.dumps({"pid":os.getpid(), "bundle":'
                                  'os.environ.get("PARLEY_EDITOR_BUNDLE")}))\n')
                editor.chmod(0o755)
                env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'])
                profile = checkout / 'demo/workspace' if recording else root / 'profile'
                if recording:
                    env.pop('PARLEY_DEMO_DIR', None)
                else:
                    env['PARLEY_DEMO_DIR'] = str(profile)
                command = [str(checkout / 'parley_app')] + (['--demo'] if recording else [])
                result = subprocess.run(command + ['file with spaces.md'], env=env,
                                        text=True, capture_output=True, timeout=10)
                self.assertEqual(0, result.returncode, result.stderr)
                observed = json.loads(result.stdout)
                bundle = profile / 'editor-dependencies'
                self.assertEqual(str(bundle / FAKE_BUNDLE), observed['bundle'])
                request = json.loads((profile / 'bundle-request.json').read_text())
                self.assertEqual('recording' if recording else 'app', request['profile'])
                self.assertEqual(str(checkout), request['runtime'])
                self.assertEqual('file with spaces.md', request['command'][-1])
                self.assertEqual(observed['pid'], request['pid'])
                self.assertEqual(str(observed['pid']), (profile / '.nvim-pid').read_text().strip())
                (profile / 'bundle-reject').touch()
                failed = subprocess.run(command, env=env, text=True, capture_output=True, timeout=10)
                self.assertEqual(23, failed.returncode, failed.stderr)
                self.assertEqual('', failed.stdout, 'Neovim ran despite failed bundle verification')
                self.assertIn('bundle verification failed', failed.stderr)
                (profile / 'bundle-reject').unlink()
                repaired = subprocess.run(command, env=env, text=True, capture_output=True, timeout=10)
                self.assertEqual(0, repaired.returncode, repaired.stderr)

    def test_refuses_redirected_dependency_root_without_touching_target(self):
        for recording in (False, True):
            with self.subTest(recording=recording), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                checkout = root / 'checkout'
                checkout.mkdir()
                shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
                profile = checkout / 'demo/workspace' if recording else root / 'profile'
                profile.mkdir(parents=True)
                (profile / '.parley-app-demo').write_text('parley_app v1\n')
                outside = root / 'outside'
                outside.mkdir()
                (outside / 'precious').write_text('keep')
                (profile / 'editor-dependencies').symlink_to(outside, target_is_directory=True)
                env = dict(os.environ)
                if recording:
                    env.pop('PARLEY_DEMO_DIR', None)
                else:
                    env['PARLEY_DEMO_DIR'] = str(profile)
                command = [str(checkout / 'parley_app')] + (['--demo'] if recording else [])
                for args in ([], ['--nuke']):
                    result = subprocess.run(command + args, env=env, text=True, capture_output=True, timeout=10)
                    self.assertNotEqual(0, result.returncode)
                    self.assertIn('editor-dependencies', result.stderr)
                    self.assertEqual(['precious'], sorted(p.name for p in outside.iterdir()))

    def test_recording_demo_selects_nested_root_and_recognizes_seed_chat(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            checkout = root / 'checkout'
            checkout.mkdir()
            shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
            (checkout / '.parley').touch()
            binaries = root / 'bin'
            binaries.mkdir()
            probe = root / 'probe.lua'
            probe.write_text('''
vim.opt.runtimepath:prepend(vim.env.TEST_RUNTIME)
require('parley.starter').start()
local p = require('parley')
local root = vim.env.PARLEY_RUNTIME .. '/demo/workspace'
assert(p.config.repo_root == root, tostring(p.config.repo_root))
assert(p.config.chat_dir == root .. '/workshop/parley')
assert(p.not_chat(vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0)) == nil)
local policy = require('parley.neighborhood').policy_for_path(
    vim.api.nvim_buf_get_name(0), p.config, p.get_chat_roots())
assert(policy.write_root == root)
assert(vim.deep_equal(policy.read_roots, {root}))
vim.cmd('qa!')
''')
            editor = binaries / 'nvim'
            editor.write_text('#!/bin/sh\nshift 2\nexec ' + shlex.quote(shutil.which('nvim'))
                              + ' --headless -u NONE -i NONE "$@" -c '
                              + shlex.quote('luafile ' + str(probe)) + '\n')
            editor.chmod(0o755)
            env = dict(os.environ, TEST_RUNTIME=str(REPO),
                       PATH=str(binaries) + os.pathsep + os.environ['PATH'])
            env.pop('PARLEY_DEMO_DIR', None)
            result = subprocess.run([str(checkout / 'parley_app'), '--demo'],
                                    env=env, text=True, capture_output=True, timeout=20)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertNotIn('Error', result.stderr)

    def test_recording_demo_launch_reset_and_isolation(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            checkout = root / 'checkout with spaces'
            checkout.mkdir()
            shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
            (checkout / 'demo').mkdir()
            (checkout / 'demo/init.lua').write_text('-- tracked config')
            (checkout / '.parley').touch()
            binaries = root / 'bin'
            binaries.mkdir()
            editor = binaries / 'nvim'
            editor.write_text('#!/usr/bin/env python3\nimport os, sys, json\n'
                              'print(json.dumps({"cwd": os.getcwd(), "args": sys.argv[1:], "env": dict(os.environ)}))\n')
            editor.chmod(0o755)
            env = dict(os.environ, HOME=str(root / 'home'), XDG_CACHE_HOME=str(root / 'cache'),
                       PATH=str(binaries) + os.pathsep + os.environ['PATH'])
            env.pop('PARLEY_DEMO_DIR', None)
            env['PARLEY_CHAT_DIR'] = str(root / 'outside-chats')
            command = [str(checkout / 'parley_app'), '--demo']
            workspace = checkout / 'demo/workspace'
            chat = workspace / ('workshop/parley/' + date.today().isoformat() + '.00-00-00.000_demo.md')

            def run(*args):
                return subprocess.run(command + list(args), cwd=root, env=env,
                                      text=True, capture_output=True, timeout=10)

            result = run()
            self.assertEqual(0, result.returncode, result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(str(workspace), observed['cwd'])
            self.assertEqual(['-u', str(checkout / 'demo/init.lua'),
                              str(chat)], observed['args'])
            self.assertEqual(str(checkout), observed['env']['PARLEY_RUNTIME'])
            self.assertNotEqual('0', observed['env'].get('PARLEY_REPO_MODE'))
            self.assertNotIn('PARLEY_CHAT_DIR', observed['env'])
            self.assertEqual(str(workspace / 'home'), observed['env']['HOME'])
            for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
                self.assertEqual(str(workspace / kind.lower()), observed['env']['XDG_' + kind + '_HOME'])
            self.assertTrue((workspace / '.parley').is_file())
            self.assertIn('💬:', chat.read_text())
            chat.write_text('trial one')
            cleared = ('state/old', 'config/old', 'cache/old', 'data/parley/parley/persisted/theme',
                       'data/parley/chats/old.md', 'data/parley/notes/old.md', 'data/parley/exports/old.md')
            retained = ('editor-dependencies/' + FAKE_BUNDLE + '/keep', 'data/parley/lazy/keep',
                        'data/parley/parley/cliproxy/config.yaml', 'home/.cli-proxy-api/login')
            for path in cleared + retained:
                leaf = workspace / path
                leaf.parent.mkdir(parents=True, exist_ok=True)
                leaf.write_text('cached')
            self.assertEqual(0, run().returncode)
            self.assertEqual('trial one', chat.read_text())
            (workspace / '.nvim-pid').write_text(str(os.getpid()))
            for args in ((), ('--reset',), ('--nuke',)):
                blocked = run(*args)
                self.assertNotEqual(0, blocked.returncode)
                self.assertIn('running', blocked.stderr)
            (workspace / '.nvim-pid').unlink()
            for flag in ('--reset', '--nuke'):
                invalid = run(flag, 'extra.md')
                self.assertNotEqual(0, invalid.returncode)
                self.assertEqual('trial one', chat.read_text())
            reset = run('--reset')
            self.assertEqual(0, reset.returncode, reset.stderr)
            self.assertNotIn('"args"', reset.stdout)
            self.assertFalse(chat.exists())
            self.assertFalse((workspace / 'state/old').exists())
            for path in cleared:
                self.assertFalse((workspace / path).exists(), path)
            for path in retained:
                self.assertEqual('cached', (workspace / path).read_text(), path)
            self.assertEqual(0, run().returncode)
            self.assertIn('💬:', chat.read_text())
            self.assertEqual(0, run('--nuke').returncode)
            self.assertTrue(workspace.exists())
            self.assertIn('💬:', chat.read_text())
            self.assertFalse((workspace / 'editor-dependencies' / FAKE_BUNDLE).exists())
            self.assertEqual('cached', (workspace / 'home/.cli-proxy-api/login').read_text())
            self.assertEqual('-- tracked config', (checkout / 'demo/init.lua').read_text())

    def test_recording_demo_rejects_symlink_ancestry_and_unowned_workspace(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            checkout = root / 'checkout'
            checkout.mkdir()
            shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
            outside = root / 'outside'
            outside.mkdir()
            (outside / 'precious').write_text('keep')
            (checkout / 'demo').symlink_to(outside, target_is_directory=True)
            command = [str(checkout / 'parley_app'), '--demo']
            env = dict(os.environ)
            env.pop('PARLEY_DEMO_DIR', None)
            for args in ([], ['--reset'], ['--nuke']):
                result = subprocess.run(command + args, env=env, text=True, capture_output=True)
                self.assertNotEqual(0, result.returncode)
            self.assertEqual(['precious'], sorted(p.name for p in outside.iterdir()))
            (checkout / 'demo').unlink()
            (checkout / 'demo/workspace').mkdir(parents=True)
            (checkout / 'demo/workspace/precious').write_text('keep')
            for args in ([], ['--reset'], ['--nuke']):
                result = subprocess.run(command + args, env=env, text=True, capture_output=True)
                self.assertNotEqual(0, result.returncode)
            self.assertEqual('keep', (checkout / 'demo/workspace/precious').read_text())

    def test_launch_serializes_with_competing_launch_and_reset(self):
        for recording, competing_args in ((False, []), (False, ["--nuke"]),
                                           (True, []), (True, ["--reset"]), (True, ["--nuke"])):
            with self.subTest(args=competing_args), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                demo = root / ("demo/workspace" if recording else "demo")
                demo.mkdir(parents=True)
                shutil.copy2(REPO / "parley_app", root / "parley_app")
                (demo / ".parley-app-demo").write_text("parley_app v1\n")
                # A completed process gives us a genuinely stale PID.
                stale = subprocess.Popen(["true"])
                stale.wait()
                (demo / ".nvim-pid").write_text(str(stale.pid))
                bin_dir = root / "bin"
                bin_dir.mkdir()
                cat = bin_dir / "cat"
                cat.write_text("#!/usr/bin/env python3\n"
                               "import os, pathlib, sys, time\n"
                               "value = pathlib.Path(sys.argv[1]).read_text()\n"
                               "root = pathlib.Path(os.environ['RACE_ROOT'])\n"
                               "if sys.argv[1].endswith('/.nvim-pid') and not (root / 'ready').exists():\n"
                               "    (root / 'ready').touch()\n"
                               "    while not (root / 'resume').exists(): time.sleep(.01)\n"
                               "sys.stdout.write(value)\n")
                cat.chmod(0o755)
                editor = bin_dir / "nvim"
                editor.write_text("#!/usr/bin/env python3\n"
                                  "import os, pathlib, time\n"
                                  "root = pathlib.Path(os.environ['RACE_ROOT'])\n"
                                  "(root / 'editor').touch()\n"
                                  "while not (root / 'stop').exists(): time.sleep(.01)\n")
                editor.chmod(0o755)
                env = dict(os.environ, PARLEY_DEMO_DIR=str(demo), RACE_ROOT=str(root),
                           PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
                command = [str((root if recording else REPO) / "parley_app")]
                if recording:
                    env.pop("PARLEY_DEMO_DIR", None)
                    command.append("--demo")
                first = subprocess.Popen(command, env=env, text=True,
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    deadline = time.monotonic() + 5
                    while not (root / "ready").exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue((root / "ready").exists(), "launcher never reached PID check")
                    second = subprocess.Popen(command + competing_args, env=env, text=True,
                                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    try:
                        _, error = second.communicate(timeout=2)
                        self.assertNotEqual(0, second.returncode, error)
                        self.assertIn("locked", error)
                    finally:
                        if second.poll() is None:
                            second.terminate()
                            second.communicate(timeout=5)
                    self.assertTrue((demo / ".parley-app-demo").exists())
                    (root / "resume").touch()
                    deadline = time.monotonic() + 5
                    while not (root / "editor").exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue((root / "editor").exists())
                    # Once launch unlocks, its published live PID still prevents reset.
                    result = subprocess.run(command + ["--nuke"], env=env, text=True,
                                            capture_output=True, timeout=5)
                    self.assertNotEqual(0, result.returncode)
                    self.assertIn("running", result.stderr)
                finally:
                    (root / "resume").touch()
                    (root / "stop").touch()
                    first.communicate(timeout=5)
                self.assertEqual(0, first.returncode)
                result = subprocess.run(command + ["--nuke"], env=env, text=True,
                                        capture_output=True, timeout=5)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertTrue(demo.exists())

    def test_launcher_lock_survives_dependency_repair_and_is_not_stolen(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            demo = root / "demo"
            demo.mkdir()
            (demo / ".parley-app-demo").write_text("parley_app v1\n")
            (demo / "chat.md").write_text("keep")
            dependencies = demo / 'editor-dependencies'
            dependencies.mkdir()
            (dependencies / '.parley-editor-owned').write_text('parley-editor-bundles-v1\n')
            (dependencies / FAKE_BUNDLE).mkdir()
            env = dict(os.environ, PARLEY_DEMO_DIR=str(demo), RACE_REPAIR_ROOT=str(root))
            command = [str(REPO / "parley_app")]
            reset = subprocess.Popen(command + ["--nuke"], env=env, text=True,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 5
                while not (root / "repaired").exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue((root / "repaired").exists())
                self.assertFalse((dependencies / FAKE_BUNDLE).exists())
                for args in ([], ["--nuke"]):
                    result = subprocess.run(command + args, env=env, text=True,
                                            capture_output=True, timeout=5)
                    self.assertNotEqual(0, result.returncode)
                    self.assertIn("locked", result.stderr)
                    self.assertEqual('keep', (demo / 'chat.md').read_text())
            finally:
                (root / "resume").touch()
                reset.communicate(timeout=5)
            self.assertEqual(0, reset.returncode)
            lock = root / "demo.launcher-lock"
            self.assertFalse(lock.exists())
            lock.mkdir()  # An abandoned lock is never stolen.
            for args in ([], ["--nuke"]):
                result = subprocess.run(command + args, env=env, text=True,
                                        capture_output=True, timeout=5)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("locked", result.stderr)
                self.assertTrue(lock.exists())
                self.assertEqual('keep', (demo / 'chat.md').read_text())

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

    def test_nuke_preserves_user_data_and_next_launch_refetches_dependencies(self):
        for recording in (False, True):
            with self.subTest(recording=recording), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                checkout = root / 'checkout'
                checkout.mkdir()
                shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
                demo = checkout / 'demo/workspace' if recording else root / 'profile'
                bin_dir = root / 'bin'
                bin_dir.mkdir()
                editor = bin_dir / 'nvim'
                editor.write_text('#!/bin/sh\nprintf launched\n')
                editor.chmod(0o755)
                env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'])
                if recording:
                    env.pop('PARLEY_DEMO_DIR', None)
                else:
                    env['PARLEY_DEMO_DIR'] = str(demo)
                command = [str(checkout / 'parley_app')] + (['--demo'] if recording else [])
                subprocess.run(command, env=env, check=True, capture_output=True)
                preserved = ('workshop/parley/chat.md', 'data/parley/chats/other.md',
                             'config/parley/init.lua', 'state/editor-state', 'cache/user-cache',
                             'home/.cli-proxy-api/login', 'data/parley/parley/cliproxy/config.yaml')
                for item in preserved:
                    path = demo / item
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('user content: ' + item)
                dependencies = demo / 'editor-dependencies'
                inode = (dependencies / '.lock').stat().st_ino
                self.assertEqual('1', (demo / 'bundle-downloads').read_text())
                for _ in range(2):
                    result = subprocess.run(command + ['--nuke'], env=env, text=True, capture_output=True, timeout=5)
                    self.assertEqual(0, result.returncode, result.stderr)
                    self.assertNotIn('launched', result.stdout)
                    self.assertFalse((dependencies / FAKE_BUNDLE).exists())
                    self.assertEqual(inode, (dependencies / '.lock').stat().st_ino)
                    self.assertEqual('parley_app v1\n', (demo / '.parley-app-demo').read_text())
                    for item in preserved:
                        self.assertEqual('user content: ' + item, (demo / item).read_text())
                subprocess.run(command, env=env, check=True, capture_output=True)
                self.assertEqual('2', (demo / 'bundle-downloads').read_text())
                self.assertTrue((dependencies / FAKE_BUNDLE / 'artifact').is_file())
                for item in preserved:
                    self.assertEqual('user content: ' + item, (demo / item).read_text())

    def test_nuke_refuses_unowned_dependencies_and_live_lease_but_absence_is_noop(self):
        for recording in (False, True):
            with self.subTest(recording=recording), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                checkout = root / 'checkout'
                checkout.mkdir()
                shutil.copy2(REPO / 'parley_app', checkout / 'parley_app')
                demo = checkout / 'demo/workspace' if recording else root / 'profile'
                demo.mkdir(parents=True)
                (demo / '.parley-app-demo').write_text('parley_app v1\n')
                (demo / 'chat.md').write_text('keep')
                env = dict(os.environ)
                if recording:
                    env.pop('PARLEY_DEMO_DIR', None)
                else:
                    env['PARLEY_DEMO_DIR'] = str(demo)
                command = [str(checkout / 'parley_app')] + (['--demo'] if recording else []) + ['--nuke']
                absent = subprocess.run(command, env=env, text=True, capture_output=True, timeout=5)
                self.assertEqual(0, absent.returncode, absent.stderr)
                self.assertEqual('keep', (demo / 'chat.md').read_text())
                dependencies = demo / 'editor-dependencies'
                dependencies.mkdir()
                (dependencies / 'precious').write_text('keep')
                unknown = subprocess.run(command, env=env, text=True, capture_output=True, timeout=5)
                self.assertNotEqual(0, unknown.returncode)
                self.assertIn('owned', unknown.stderr)
                self.assertEqual('keep', (dependencies / 'precious').read_text())
                (dependencies / 'precious').unlink()
                (dependencies / '.parley-editor-owned').write_text('parley-editor-bundles-v1\n')
                (dependencies / FAKE_BUNDLE).mkdir()
                with (dependencies / '.lock').open('w') as lease:
                    fcntl.flock(lease, fcntl.LOCK_SH)
                    blocked = subprocess.run(command, env=env, text=True, capture_output=True, timeout=5)
                self.assertNotEqual(0, blocked.returncode)
                self.assertIn('lease busy', blocked.stderr)
                self.assertIn('Clearing cached editor dependencies', blocked.stderr)
                self.assertTrue((dependencies / FAKE_BUNDLE).exists())
                self.assertEqual('keep', (demo / 'chat.md').read_text())

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
