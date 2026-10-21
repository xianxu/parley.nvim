"""Executable contract checks for the test-only operator protocol fake."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

FIXTURE = Path(__file__).resolve().parents[1] / 'fixtures' / 'fake_couch_operator.py'
TOKEN = 'a' * 32


class OperatorFakeTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.doc = self.root / 'session.md'
        self.doc.write_text('before\n')
        self.lock = Path(str(self.doc) + '.lock')

    def request(self, op='operator-acquire', token=TOKEN, identity='doc-1', env=None, path=None):
        result = subprocess.run([sys.executable, str(FIXTURE), '--session-sync', op,
                                 str(path or self.doc), '--id', identity, '--turn', token, '--json'],
                                env=dict(os.environ, **(env or {})), capture_output=True, text=True)
        self.assertTrue(result.stdout.strip(), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def test_invalid_identity_and_usage_are_explicit_before_store_io(self):
        env = dict(os.environ, FAKE_COUCH_REGISTRY=str(self.root / 'absent' / 'registry.json'))
        result = subprocess.run([sys.executable, str(FIXTURE), '--session-sync', 'operator-acquire',
                                 str(self.doc), '--id', 'doc-1', '--turn', 'invalid', '--json'],
                                capture_output=True, text=True, env=env, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['Code'], 'operator-invalid')
        result = subprocess.run([sys.executable, str(FIXTURE), '--session-sync', 'operator-acquire'],
                                capture_output=True, text=True, env=env, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)['Code'], 'usage')
        self.assertFalse((self.root / 'absent').exists())

    def test_acquire_replay_release_and_stale_release(self):
        exit_code, reply = self.request()
        self.assertEqual(exit_code, 0)
        owned = reply['OperatorLock']
        self.assertEqual(owned['State'], 'acquired')
        self.assertEqual(owned['ID'], 'doc-1')
        self.assertEqual(owned['File'], str(self.doc.resolve()))
        self.assertEqual(owned['LockPath'], str(self.lock))
        self.assertEqual(owned['LockText'], self.lock.read_text())
        for field in ('holder: operator', 'document: doc-1', 'turn: ' + TOKEN):
            self.assertEqual(owned['LockText'].splitlines().count(field), 1)
        self.assertEqual(self.request()[1]['OperatorLock']['State'], 'already-held')
        self.assertEqual(self.lock.read_text(), owned['LockText'])
        self.assertEqual(self.request('operator-release', token='b' * 32)[0], 3)
        self.assertEqual(self.lock.read_text(), owned['LockText'])
        self.assertEqual(self.request('operator-release')[1]['OperatorLock']['State'], 'released')
        self.assertFalse(self.lock.exists())
        absent = self.request('operator-release')[1]['OperatorLock']
        self.assertEqual(absent['State'], 'already-released')
        self.assertEqual(absent['Turn'], TOKEN)
        self.assertFalse(absent.get('LockText'))

    def test_foreign_legacy_and_malformed_lock_refuse_without_effect(self):
        for content in ('holder: operator\nsince: 1\n',
                        'holder: operator\ndocument: doc-1\nturn: ' + TOKEN + '\nturn: duplicate\n'):
            self.lock.write_text(content)
            code, reply = self.request()
            self.assertEqual(code, 3)
            self.assertEqual(reply['Code'], 'operator-lock')
            self.assertEqual(self.lock.read_text(), content)

    def test_agent_sidecar_is_free_and_release_preserves_it(self):
        text = 'holder: agent\ntime: 2026-10-21T10:00:00Z\n'
        self.lock.write_text(text)
        code, reply = self.request('operator-release')
        self.assertEqual(code, 0)
        self.assertEqual(reply['OperatorLock']['State'], 'already-released')
        self.assertEqual(self.lock.read_text(), text)
        code, reply = self.request()
        self.assertEqual(code, 0)
        self.assertEqual(reply['OperatorLock']['State'], 'acquired')
        self.assertIn('holder: operator', self.lock.read_text())

    def test_registry_identity_and_rename(self):
        registry = self.root / 'registry.json'
        registry.write_text(json.dumps({'paths': {str(self.doc): {'ID': 'registered'}}}))
        env = {'FAKE_COUCH_REGISTRY': str(registry)}
        self.assertEqual(self.request(env=env)[0], 1)
        self.assertFalse(self.lock.exists())
        self.assertEqual(self.request(identity='registered', env=env)[0], 0)
        new = self.root / 'renamed.md'
        self.doc.rename(new)
        self.lock.rename(str(new) + '.lock')
        registry.write_text(json.dumps({'paths': {str(new): {'ID': 'registered'}}}))
        self.assertEqual(self.request('operator-release', identity='registered', env=env, path=new)[0], 0)
        self.assertFalse(Path(str(new) + '.lock').exists())

    def test_failure_race_trace_and_malformed_ack_injection(self):
        trace = self.root / 'requests.jsonl'
        env = {'FAKE_COUCH_OPERATOR_TRACE': str(trace), 'FAKE_COUCH_OPERATOR_CODE': 'session-sync-unavailable',
               'FAKE_COUCH_OPERATOR_EXIT': '7'}
        code, reply = self.request(env=env)
        self.assertEqual((code, reply['Code']), (7, 'session-sync-unavailable'))
        self.assertFalse(self.lock.exists())
        self.assertEqual(len(trace.read_text().splitlines()), 1)
        result = subprocess.run([sys.executable, str(FIXTURE), '--session-sync', 'operator-acquire', str(self.doc),
                                 '--id', 'doc-1', '--turn', TOKEN, '--json'],
                                env=dict(os.environ, FAKE_COUCH_OPERATOR_ACQUIRE_WRITE='raced\n',
                                         FAKE_COUCH_OPERATOR_ACK='{broken'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), '{broken')
        self.assertTrue(self.lock.exists())
        self.assertEqual(self.doc.read_text(), 'raced\n')

    def test_lost_reply_kills_without_pipe_leak_and_replays_exact_ownership(self):
        trace = self.root / 'delayed.jsonl'
        args = [sys.executable, str(FIXTURE), '--session-sync', 'operator-acquire', str(self.doc),
                '--id', 'doc-1', '--turn', TOKEN, '--json']
        process = subprocess.Popen(args, env=dict(os.environ, FAKE_COUCH_OPERATOR_DELAY='30',
                                   FAKE_COUCH_OPERATOR_TRACE=str(trace)),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline = time.monotonic() + 5
        while not self.lock.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue(self.lock.exists(), 'acquire never published its lock')
        owned = self.lock.read_text()
        process.terminate()
        stdout, _ = process.communicate(timeout=1)
        self.assertEqual(stdout, '')
        code, reply = self.request()
        self.assertEqual(code, 0)
        self.assertEqual(reply['OperatorLock']['State'], 'already-held')
        self.assertEqual(reply['OperatorLock']['LockText'], owned)
        self.assertEqual(self.lock.read_text(), owned)

    def test_turn_validation(self):
        for token in ('', 'A' * 32, 'a' * 31, 'g' * 32):
            self.assertEqual(self.request(token=token)[0], 1)
        self.assertFalse(self.lock.exists())


if __name__ == '__main__':
    unittest.main()
