"""Consumer integration tests use actual owned subprocesses and pipes."""
import asyncio
import importlib.util
import os
from pathlib import Path
import signal
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('couch_bridge', ROOT / 'scripts/couch_bridge.py')
module = importlib.util.module_from_spec(spec)
if spec.loader and (ROOT / 'scripts/couch_bridge.py').exists():
    spec.loader.exec_module(module)
BridgeSession = getattr(module, 'BridgeSession', None)

class SessionTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        scratch = '/Volumes/TestScratch' if Path('/Volumes/TestScratch').is_dir() else None
        self.tmp = tempfile.TemporaryDirectory(prefix='bridge-consumer-', dir=scratch)
        self.root = Path(self.tmp.name).resolve() / 'producer'

    async def asyncTearDown(self):
        self.tmp.cleanup()

    def session(self, mode='ok', **kw):
        self.assertIsNotNone(BridgeSession, 'BridgeSession API is implemented')
        return BridgeSession([sys.executable, str(ROOT / 'tests/fixtures/fake_couch_bridge.py'), str(self.root), mode],
                             env={'PATH': os.defpath}, startup_s=kw.pop('startup_s', 1),
                             lifetime_s=kw.pop('lifetime_s', 4), stop_s=kw.pop('stop_s', .15),
                             margin_s=kw.pop('margin_s', .3), **kw)

    async def test_fixture_exits_with_parent_while_stdin_remains_open(self):
        read_fd, write_fd = os.pipe()
        parent = None
        try:
            # Keep the fixture's stdin open independently of its direct parent:
            # parent death must release it even when stdin cannot deliver EOF.
            code = ('import subprocess,sys; '
                    'subprocess.Popen(sys.argv[1:-1], stdin=int(sys.argv[-1])); '
                    'sys.stdin.buffer.read(1)')
            parent = await asyncio.create_subprocess_exec(
                sys.executable, '-c', code, sys.executable,
                str(ROOT / 'tests/fixtures/fake_couch_bridge.py'),
                str(self.root), 'ok', str(read_fd), pass_fds=(read_fd,),
                stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE)
            readiness = await asyncio.wait_for(parent.stdout.readline(), 4)
            self.assertIn(b'"Version": 1', readiness)
            self.assertFalse((self.root / 'eof').exists())
            parent.terminate()
            # wait() may wait for the inherited stdout pipe too; observe its
            # EOF first so a surviving fixture cannot hide behind parent exit.
            try:
                remaining = await asyncio.wait_for(parent.stdout.read(), 4)
            except asyncio.TimeoutError:
                self.fail('fixture survived parent death with stdin still open')
            self.assertEqual(remaining, b'')
            self.assertFalse((self.root / 'eof').exists())
            self.assertFalse((self.root / 'cleaned').exists())
        finally:
            os.close(read_fd)
            os.close(write_fd)
            if parent is not None:
                if parent.returncode is None:
                    parent.terminate()
                await asyncio.wait_for(parent.communicate(), 4)

    async def test_success_and_full_environment(self):
        s = self.session()
        async with s:
            self.assertTrue(s.readiness['Extra']['preserved'])
            result = await s.run([sys.executable, '-c', 'import os; print(os.getenv("ONLY")); print(os.getenv("HOME"))'], env=s.readiness['Environment'])
            self.assertEqual(result.stdout, 'replacement\nNone\n')
            self.assertEqual(result.returncode, 0)
        self.assertTrue(s.cleaned)
        self.assertTrue((self.root / 'cleaned').exists())

    async def test_flood_drains_during_probe_and_keeps_tail(self):
        s = self.session('flood')
        async with s:
            code = 'import pathlib,time; p=pathlib.Path(' + repr(str(self.root / 'flooded')) + ');\nwhile not p.exists(): time.sleep(.01)'
            await s.run([sys.executable, '-c', code], env={}, timeout=1)
        self.assertIn('retained-root: ' + str(self.root), s.diagnostics)
        self.assertIn('truncated', s.diagnostics)
        self.assertLess(len(s.diagnostics.encode()), 66000)

    async def test_invalid_readiness_is_joined(self):
        for mode in ['malformed', 'duplicate', 'oversize', 'partial', 'empty', 'second']:
            with self.subTest(mode=mode):
                s = self.session(mode, startup_s=.15)
                with self.assertRaises(RuntimeError):
                    async with s:
                        await asyncio.sleep(.05)
                self.assertFalse(s.cleaned)
                self.assertTrue((self.root / 'evidence').exists())
                pid = int((self.root / 'pid').read_text())
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)

    async def test_startup_deadline(self):
        s = self.session('delay', startup_s=.05)
        with self.assertRaises(RuntimeError):
            async with s:
                pass
        self.assertFalse(s.cleaned)
        self.assertTrue((self.root / 'evidence').exists())

    async def test_nonzero_and_uncertain_stop_preserve_evidence(self):
        for mode in ['nonzero', 'hang']:
            s = self.session(mode)
            with self.assertRaises(RuntimeError):
                async with s:
                    pass
            self.assertFalse(s.cleaned)
            self.assertTrue((self.root / 'evidence').exists())
            self.assertIn(str(self.root), s.diagnostics)

    async def test_probe_timeout_joins_before_eof(self):
        s = self.session()
        async with s:
            code = 'import os,pathlib,time; pathlib.Path(' + repr(str(self.root / 'probe')) + ').write_text(str(os.getpid())); time.sleep(10)'
            with self.assertRaises((TimeoutError, asyncio.TimeoutError)):
                await s.run([sys.executable, '-c', code], env={}, timeout=.1)
            pid = int((self.root / 'probe').read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)
            self.assertFalse((self.root / 'eof').exists())
        self.assertTrue(s.cleaned)

    async def test_probe_cancellation_joins_before_eof(self):
        s = self.session()
        async with s:
            task = asyncio.create_task(s.run([sys.executable, '-c', 'import time; time.sleep(10)'], env={}))
            await asyncio.sleep(.07)
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
            self.assertFalse((self.root / 'eof').exists())
        self.assertTrue(s.cleaned)

    async def test_cancellation_during_exit_joins_producer(self):
        s = self.session('hang')
        async def use():
            async with s:
                pass
        task = asyncio.create_task(use())
        await asyncio.sleep(.08)
        task.cancel()
        with self.assertRaises((RuntimeError, asyncio.CancelledError)):
            await task
        pid = int((self.root / 'pid').read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    async def test_no_signal_after_successful_probe(self):
        s = self.session()
        calls = []
        killpg = os.killpg
        def observe(pid, sig):
            calls.append((pid, sig))
            killpg(pid, sig)
        with patch.object(module.os, 'killpg', side_effect=observe):
            async with s:
                result = await s.run([sys.executable, '-c', 'pass'], env={})
                self.assertEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    async def test_no_late_signal_after_bridge_exit(self):
        s = self.session('early', lifetime_s=.12)
        with patch.object(module.os, 'killpg') as send:
            with self.assertRaises(RuntimeError):
                async with s:
                    await s._join
                    await asyncio.sleep(.25)
            send.assert_not_called()
        self.assertFalse(s.cleaned)

    async def test_probe_descendant_pipe_is_unknown_after_leader_exit(self):
        s = self.session()
        child = 'import time; time.sleep(10)'
        code = 'import subprocess,sys,pathlib; p=subprocess.Popen([sys.executable,"-c",' + repr(child) + ']); pathlib.Path(' + repr(str(self.root / 'descendant')) + ').write_text(str(p.pid))'
        pid = None
        try:
            with self.assertRaises(RuntimeError):
                async with s:
                    with patch.object(module.os, 'killpg') as send:
                        with self.assertRaises(TimeoutError):
                            await s.run([sys.executable, '-c', code], env={}, timeout=.15)
                        pid = int((self.root / 'descendant').read_text())
                        send.assert_not_called()
            self.assertFalse(s.cleaned)
            self.assertIn('cleanup unknown', s._failure)
        finally:
            if pid:
                os.kill(pid, signal.SIGKILL)

    async def test_invalid_known_shapes(self):
        import json
        valid = {'Version': 1, 'Namespace': str(self.root), 'Socket': str(self.root / 'ipc'),
                 'Environment': {'PATH': '/private/bin'},
                 'Documents': [{'ID': 'a' * 32, 'File': str(self.root / 'parent.md')},
                               {'ID': 'b' * 32, 'File': str(self.root / 'parent.side/child.md')}]}
        for key, value in [('Version', True), ('Socket', 'relative'), ('Namespace', '/tmp/../tmp'),
                           ('Environment', {'PATH': 7}), ('Environment', {'PATH': '/bin', '': 'invalid'}), ('Documents', [])]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                module._readiness(json.dumps(dict(valid, **{key: value})))
        with self.assertRaises(ValueError):
            module._readiness(json.dumps(valid).replace('\"PATH\": \"/private/bin\"', '\"PATH\": \"/private/bin\", \"PATH\": \"/other\"'))
        valid['Documents'][1]['ID'] = 'a' * 32
        with self.assertRaises(ValueError):
            module._readiness(json.dumps(valid))

    async def test_probe_failure_is_returned(self):
        s = self.session()
        async with s:
            result = await s.run([sys.executable, '-c', 'import sys; print("bad", file=sys.stderr); sys.exit(7)'], env={})
            self.assertEqual(result.returncode, 7)
            self.assertEqual(result.stderr, 'bad\n')
        self.assertTrue(s.cleaned)

    async def test_lifetime_is_absolute(self):
        s = self.session(lifetime_s=.22)
        with self.assertRaises(RuntimeError):
            async with s:
                await asyncio.sleep(.12)
                await s.run([sys.executable, '-c', 'import time; time.sleep(.3)'], env={}, timeout=1)
        self.assertFalse(s.cleaned)

if __name__ == '__main__':
    unittest.main()
