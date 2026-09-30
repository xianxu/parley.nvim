"""Total archive deadlines against real trickling HTTP responses."""
import hashlib
import http.server
import importlib.util
import os
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/editor-dependencies.py'
spec = importlib.util.spec_from_file_location('editor_downloads', SCRIPT)
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class Downloads(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.servers = []
        self.addCleanup(self.stop_servers)

    def stop_servers(self):
        for server in self.servers:
            server.shutdown()
            server.server_close()

    def serve(self, mode):
        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                try:
                    if mode == 'headers':
                        # Keep the header parser receiving data more often than
                        # the socket timeout, without completing the headers.
                        self.wfile.write(b'HTTP/1.1 200 OK\r\nX-Drip: ')
                        self.wfile.flush()
                        for _ in range(30):
                            self.wfile.write(b'x')
                            self.wfile.flush()
                            time.sleep(.025)
                        self.wfile.write(b'\r\nContent-Length: 1\r\n\r\nx')
                    else:
                        payload = b'x' * (30 if mode == 'body' else 1)
                        self.send_response(200)
                        self.send_header('Content-Length', str(len(payload)))
                        self.end_headers()
                        for byte in payload:
                            self.wfile.write(bytes([byte]))
                            self.wfile.flush()
                            if mode == 'body':
                                time.sleep(.025)
                except (BrokenPipeError, ConnectionResetError):
                    pass
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        server.daemon_threads = True
        self.servers.append(server)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return 'http://127.0.0.1:%s/archive.tar.gz' % server.server_port

    def record(self, url, payload=b'x'):
        return {'url': url, 'sha256': hashlib.sha256(payload).hexdigest()}

    def assert_deadline(self, mode):
        destination = self.root / 'download'
        record = self.record(self.serve(mode), b'x' * (30 if mode == 'body' else 1))
        processes = []
        original = bundle.subprocess.Popen
        def spawn(*args, **kwargs):
            process = original(*args, **kwargs)
            processes.append(process)
            return process
        started = time.monotonic()
        with mock.patch.object(bundle, 'TIMEOUT', .1), mock.patch.object(bundle.subprocess, 'Popen', side_effect=spawn):
            with self.assertRaisesRegex(ValueError, 'time|deadline'):
                bundle.fetch_archive(record, destination)
        elapsed = time.monotonic() - started
        # Old socket-only timeout takes ~.75s despite the .1s limit. Allow
        # scheduling/reaping overhead without admitting a completed drip.
        self.assertLess(elapsed, .4)
        self.assertEqual(1, len(processes))
        self.assertIsNotNone(processes[0].returncode)
        with self.assertRaises(ChildProcessError):
            os.waitpid(processes[0].pid, os.WNOHANG)
        self.assertFalse(destination.exists(), 'failed downloads must not leave partial files')
        time.sleep(.1)
        self.assertFalse(destination.exists(), 'worker must not continue writing after timeout')

    def test_total_deadline_includes_dripping_response_body(self):
        self.assert_deadline('body')

    def test_total_deadline_includes_dripping_response_headers(self):
        self.assert_deadline('headers')

    def test_worker_has_its_own_deadline_without_parent_fetch_watchdog(self):
        record = self.record(self.serve('body'), b'x' * 30)
        with (self.root / 'direct-worker').open('xb') as output:
            started = time.monotonic()
            process = subprocess.Popen([
                sys.executable, '-c',
                "import runpy,sys; runpy.run_path(sys.argv[1])['_download_worker'](*sys.argv[2:])",
                str(SCRIPT), json.dumps(record), str(output.fileno()), '', '.1', '1048576',
            ], pass_fds=(output.fileno(),), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                _, error = process.communicate(timeout=2)
                self.assertLess(time.monotonic() - started, .5)
                self.assertNotEqual(0, process.returncode)
                self.assertIn(b'deadline', error)
                with self.assertRaises(ChildProcessError):
                    os.waitpid(process.pid, os.WNOHANG)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_success_and_hash_failure_use_real_response_bytes(self):
        record = self.record(self.serve('complete'))
        destination = self.root / 'download'
        bundle.fetch_archive(record, destination)
        self.assertEqual(b'x', destination.read_bytes())
        record['sha256'] = '0' * 64
        failure = self.root / 'bad-download'
        with self.assertRaisesRegex(ValueError, 'checksum'):
            bundle.fetch_archive(record, failure)
        self.assertFalse(failure.exists())

    def test_local_archive_reads_share_deadline_and_size_limit(self):
        cached = self.root / 'archive.tar.gz'
        cached.write_bytes(b'x' * 100)
        record = self.record('https://unused.invalid/archive.tar.gz', cached.read_bytes())
        output = self.root / 'output'
        with mock.patch.object(bundle, 'TIMEOUT', .001):
            with self.assertRaisesRegex(ValueError, 'time|deadline'):
                bundle.fetch_archive(record, output, self.root)
        self.assertFalse(output.exists())
        with mock.patch.object(bundle, 'MAX_ARCHIVE_BYTES', 10):
            with self.assertRaisesRegex(ValueError, 'size'):
                bundle.fetch_archive(record, output, self.root)
        self.assertFalse(output.exists())

    def test_failed_download_preserves_preexisting_destination(self):
        destination = self.root / 'existing'
        destination.write_bytes(b'owned by caller')
        with self.assertRaises((OSError, ValueError)):
            bundle.fetch_archive(self.record(self.serve('complete')), destination)
        self.assertEqual(b'owned by caller', destination.read_bytes())


if __name__ == '__main__':
    unittest.main()
