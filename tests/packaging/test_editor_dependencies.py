"""Artifact and lease tests use real archives, HTTP responses and subprocesses."""
import contextlib
import copy
import fcntl
import functools
import hashlib
import http.server
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/editor-dependencies.py'
spec = importlib.util.spec_from_file_location('editor_dependencies', SCRIPT)
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def archive(path, files):
    with tarfile.open(path, 'w:gz') as stream:
        for name, data, mode in files:
            item = tarfile.TarInfo(name)
            item.size, item.mode = len(data), mode
            stream.addfile(item, io.BytesIO(data))
    return sha(path.read_bytes())


class Artifacts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archives = self.root / 'archives'
        self.archives.mkdir()
        self.requests = []
        requests = self.requests

        class Handler(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                requests.append(self.path)
                return super().do_GET()

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=self.archives))
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        base = 'http://127.0.0.1:' + str(self.server.server_port)
        # Real Git archive establishes the same root/commit provenance as upstream.
        repo = self.root / 'repo'
        repo.mkdir()
        (repo / 'LICENSE').write_text('fixture license\n')
        (repo / 'init.lua').write_text('return {}\n')
        env = dict(os.environ, GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                   GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        for args in (['init', '-q'], ['add', '.'], ['commit', '-qm', 'fixture']):
            subprocess.run(['git', '-C', str(repo), *args], env=env, check=True, capture_output=True)
        commit = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
        source = self.archives / ('markdown-preview.nvim-' + commit + '.tar.gz')
        subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar.gz', '--prefix=source/', '-o', str(source), 'HEAD'], check=True)
        binary = b'#!/bin/sh\necho fixture\n'
        artifact = self.archives / 'preview.tar.gz'
        checksum = archive(artifact, [('preview', binary, 0o755)])
        self.manifest = {'schema_version': 1, 'plugins': [dict(name='markdown-preview.nvim', repo='fixture/preview',
            commit=commit, scope='app', url=base + '/' + source.name, sha256=sha(source.read_bytes()))],
            'artifact': dict(platform='test', version='1', url=base + '/preview.tar.gz', sha256=checksum,
                             binary_sha256=sha(binary), member='preview', output='plugins/markdown-preview.nvim/app/bin/preview')}
        self.manifest_path = self.root / 'manifest.json'
        self.manifest_path.write_text(json.dumps(self.manifest))
        self.cache = self.root / 'cache'

    def prepare(self, **kwargs):
        return bundle.prepare_bundle(self.cache, self.manifest, **kwargs)

    def cli(self, *args):
        return [sys.executable, str(SCRIPT), '--manifest', str(self.manifest_path), *map(str, args)]

    def test_manifest_rejects_ambiguous_and_escaping_identity(self):
        bundle.validate_manifest(self.manifest)
        for change in ('duplicate', 'name', 'commit', 'checksum', 'output', 'schema'):
            invalid = copy.deepcopy(self.manifest)
            if change == 'duplicate': invalid['plugins'].append(copy.deepcopy(invalid['plugins'][0]))
            if change == 'name': invalid['plugins'][0]['name'] = '../escape'
            if change == 'commit': invalid['plugins'][0]['commit'] = 'main'
            if change == 'checksum': invalid['plugins'][0]['sha256'] = 'a'
            if change == 'output': invalid['artifact']['output'] = '../escape'
            if change == 'schema': invalid['schema_version'] = True
            with self.subTest(change=change), self.assertRaises(ValueError):
                bundle.validate_manifest(invalid)

    def test_member_type_and_path_allowlist(self):
        for name, kind in [('../escape', tarfile.REGTYPE), ('/absolute', tarfile.REGTYPE),
                           ('x/../../escape', tarfile.REGTYPE), ('a\\b', tarfile.REGTYPE),
                           ('link', tarfile.SYMTYPE), ('link', tarfile.LNKTYPE), ('device', tarfile.CHRTYPE)]:
            member = tarfile.TarInfo(name)
            member.type = kind
            with self.subTest(name=name, kind=kind), self.assertRaises(ValueError):
                bundle.validate_member(member)
        bundle.validate_member(tarfile.TarInfo('source/lua/init.lua'))

    def test_publication_decision_table(self):
        self.assertEqual('assemble', bundle.publication_action(False, False))
        self.assertEqual('reuse', bundle.publication_action(True, True))
        self.assertEqual('repair', bundle.publication_action(True, False))

    def test_http_assembly_reuse_and_full_payload_verification(self):
        path = self.prepare()
        self.assertEqual(2, len(self.requests))
        self.assertEqual(path, self.prepare())
        self.assertEqual(2, len(self.requests))
        report = bundle.verify_bundle(path, self.manifest)
        self.assertEqual(self.manifest, report['manifest'])
        self.assertTrue((path / 'plugins/markdown-preview.nvim/LICENSE').is_file())
        for mutation in ('modified', 'extra', 'missing', 'mode'):
            file = path / 'plugins/markdown-preview.nvim/init.lua'
            original = file.read_bytes()
            if mutation == 'modified': file.write_bytes(b'bad')
            if mutation == 'extra': (path / 'unexpected.lua').write_text('bad')
            if mutation == 'missing': file.unlink()
            if mutation == 'mode': file.chmod(0o755)
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, 'payload'):
                bundle.verify_bundle(path, self.manifest)
            if mutation == 'extra': (path / 'unexpected.lua').unlink()
            file.write_bytes(original)
            file.chmod(0o644)

    def test_corrupt_cache_fails_closed_and_explicit_repair_is_owned(self):
        path = self.prepare()
        (path / 'plugins/markdown-preview.nvim/init.lua').write_text('bad')
        with self.assertRaisesRegex(ValueError, 'repair'):
            self.prepare()
        self.assertTrue(path.exists())
        bundle.repair_bundle(self.cache)
        self.assertFalse(path.exists())
        self.assertTrue((self.cache / '.lock').exists())
        unknown = self.root / 'user'
        unknown.mkdir()
        with self.assertRaisesRegex(ValueError, 'owned'):
            bundle.repair_bundle(unknown)

    def test_checksum_failure_and_interrupted_publication_leave_no_selected_stage(self):
        bad = copy.deepcopy(self.manifest)
        bad['artifact']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'checksum'):
            bundle.prepare_bundle(self.cache, bad)
        self.assertFalse(list(self.cache.glob('staging-*')))
        with mock.patch.object(bundle.os, 'rename', side_effect=OSError('interrupted')):
            with self.assertRaisesRegex(OSError, 'interrupted'):
                self.prepare()
        self.assertFalse(list(self.cache.glob('bundle-*')))
        self.assertFalse(list(self.cache.glob('staging-*')))
        self.assertTrue(self.prepare().exists())

    def test_archive_cache_still_checks_hash_and_size_and_retention(self):
        path = self.prepare(archives=self.archives)
        self.assertEqual([], self.requests)
        orphan = self.cache / 'staging-interrupted'
        orphan.mkdir()
        (orphan / 'partial').write_text('partial')
        changed = copy.deepcopy(self.manifest)
        changed['artifact']['version'] = '2'
        latest = bundle.prepare_bundle(self.cache, changed, archives=self.archives)
        self.assertNotEqual(path, latest)
        self.assertFalse(path.exists())
        self.assertFalse(orphan.exists())
        self.assertEqual([latest], list(self.cache.glob('bundle-*')))
        with mock.patch.object(bundle, 'MAX_ARCHIVE_BYTES', 1), self.assertRaisesRegex(ValueError, 'size'):
            bundle.prepare_bundle(self.root / 'tiny', self.manifest, archives=self.archives)

    def test_failed_new_version_preserves_previous_published_bundle(self):
        path = self.prepare()
        changed = copy.deepcopy(self.manifest)
        changed['artifact']['sha256'] = '0' * 64
        with self.assertRaises(ValueError):
            bundle.prepare_bundle(self.cache, changed)
        self.assertTrue(path.exists())
        bundle.verify_bundle(path, self.manifest)
        with mock.patch.object(bundle, 'seal_bundle', side_effect=RuntimeError('verification interrupted')):
            changed['artifact'] = dict(self.manifest['artifact'], version='2')
            with self.assertRaises(RuntimeError):
                bundle.prepare_bundle(self.cache, changed)
        self.assertTrue(path.exists())
        self.assertFalse(list(self.cache.glob('staging-*')))

    def test_malformed_manifest_values_raise_validation_errors(self):
        for field, value in [('repo', []), ('name', {}), ('url', None), ('scope', [])]:
            invalid = copy.deepcopy(self.manifest)
            invalid['plugins'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                bundle.validate_manifest(invalid)

    def test_receipt_parser_binding_duplicates_and_invalid_inventory(self):
        path = self.prepare()
        receipt = json.loads((path / 'receipt.json').read_text())
        bundle.parse_receipt(json.dumps(receipt), self.manifest)
        for key, value in [('schema_version', 2), ('manifest', {}), ('files', {'../escape': {}})]:
            invalid = dict(receipt, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                bundle.parse_receipt(json.dumps(invalid), self.manifest)
        with self.assertRaises(ValueError):
            bundle.parse_receipt('{"schema_version":1,"schema_version":1}', self.manifest)

    def test_seal_requires_exact_plugin_set_and_binary_identity(self):
        path = self.prepare()
        (path / 'receipt.json').unlink()
        bundle.seal_bundle(path, self.manifest)
        binary = path / self.manifest['artifact']['output']
        binary.write_text('wrong')
        with self.assertRaisesRegex(ValueError, 'binary'):
            bundle.seal_bundle(path, self.manifest)

    def test_symlinks_and_archive_duplicate_destinations_fail(self):
        path = self.prepare()
        (path / 'extra').symlink_to('/tmp')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            bundle.verify_bundle(path, self.manifest)
        duplicate = self.archives / 'duplicate.tar.gz'
        checksum = archive(duplicate, [('source/a', b'a', 0o644), ('source/a', b'b', 0o644)])
        changed = copy.deepcopy(self.manifest)
        changed['plugins'][0].update(url='file://' + str(duplicate), sha256=checksum)
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            bundle.prepare_bundle(self.root / 'duplicate-cache', changed)

    def test_downgrade_rechecks_bundle_before_executing_consumer(self):
        path = self.prepare()
        original = fcntl.flock
        def conversion(fd, mode):
            # flock conversions need not be atomic. Model a competing writer
            # collecting the old version in the conversion's unlocked interval.
            if mode == fcntl.LOCK_SH:
                shutil.rmtree(path)
            return original(fd, mode)
        with mock.patch.object(bundle.fcntl, 'flock', side_effect=conversion), mock.patch.object(bundle.os, 'execvp') as execute:
            with self.assertRaises(ValueError):
                bundle.run_with_bundle(self.cache, self.manifest, ['unused'])
            execute.assert_not_called()

    def test_real_exec_shared_lease_blocks_writer_until_consumer_exits(self):
        ready, stop = self.root / 'ready', self.root / 'stop'
        consumer = 'import os,time,pathlib; pathlib.Path(os.environ["READY"]).write_text(os.environ["PARLEY_EDITOR_BUNDLE"]);\nwhile not pathlib.Path(os.environ["STOP"]).exists(): time.sleep(.02)'
        env = dict(os.environ, READY=str(ready), STOP=str(stop))
        proc = subprocess.Popen(self.cli('run', '--root', self.cache, '--', sys.executable, '-c', consumer), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(lambda: proc.poll() is None and proc.kill())
        deadline = time.monotonic() + 5
        while not ready.exists() and proc.poll() is None and time.monotonic() < deadline: time.sleep(.02)
        self.assertTrue(ready.exists(), proc.stderr.read() if proc.poll() is not None else 'consumer not ready')
        inode = (self.cache / '.lock').stat().st_ino
        blocked = subprocess.run(self.cli('--lock-timeout', '.1', 'repair', '--root', self.cache), capture_output=True, text=True)
        self.assertNotEqual(0, blocked.returncode)
        self.assertIn('lease', blocked.stderr)
        self.assertTrue(Path(ready.read_text()).exists())
        stop.touch()
        self.assertEqual(0, proc.wait(timeout=5))
        proc.stdout.close(); proc.stderr.close()
        bundle.repair_bundle(self.cache)
        self.assertEqual(inode, (self.cache / '.lock').stat().st_ino)

    @unittest.skipUnless(shutil.which('nvim'), 'Neovim required for exec descriptor conformance')
    def test_nvim_retains_lease_when_its_parent_terminates(self):
        ready, stop, pidfile = self.root / 'ready', self.root / 'stop', self.root / 'pid'
        lua = self.root / 'consumer.lua'
        lua.write_text("local f=assert(io.open(vim.env.READY,'w')); f:write(vim.env.PARLEY_EDITOR_BUNDLE); f:close(); "
            "local t=vim.uv.new_timer(); t:start(20,20,vim.schedule_wrap(function() if vim.uv.fs_stat(vim.env.STOP) then t:stop();t:close();vim.cmd('qa!') end end))")
        launcher = self.root / 'parent.py'
        launcher.write_text('import subprocess,sys,time,pathlib\np=subprocess.Popen(sys.argv[2:])\npathlib.Path(sys.argv[1]).write_text(str(p.pid))\ntime.sleep(30)\n')
        env = dict(os.environ, READY=str(ready), STOP=str(stop))
        proc = subprocess.Popen([sys.executable, str(launcher), str(pidfile), *self.cli('run','--root',self.cache,'--',shutil.which('nvim'),'--headless','-u','NONE','-i','NONE','-n','-c','luafile ' + str(lua))], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        child = None
        try:
            deadline = time.monotonic() + 8
            while not ready.exists() and time.monotonic() < deadline: time.sleep(.02)
            self.assertTrue(ready.exists())
            child = int(pidfile.read_text())
            proc.terminate(); proc.wait(timeout=5)
            with (self.cache / '.lock').open('r') as lock:
                with self.assertRaises(BlockingIOError): fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                stop.touch()
                deadline = time.monotonic() + 5
                while True:
                    try:
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                        break
                    except BlockingIOError:
                        if time.monotonic() > deadline: self.fail('Neovim did not release lease')
                        time.sleep(.02)
            child = None
        finally:
            if proc.poll() is None: proc.terminate(); proc.wait(timeout=5)
            if child:
                with contextlib.suppress(ProcessLookupError): os.kill(child, 15)


if __name__ == '__main__':
    unittest.main()
