#!/usr/bin/env python3
"""Assemble immutable editor bundles; hold a kernel lease through editor exec.

No downloaded code is executed. Homebrew's checksum-verified resource staging may
be sealed directly; writable development bundles are fully hashed at every use.
"""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request

MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
MAX_UNPACKED_BYTES = 512 * 1024 * 1024
MAX_MEMBERS = 50000
TIMEOUT = 120
OWNER = 'parley-editor-bundles-v1\n'
MARKER = '.parley-editor-owned'
_show_progress = False


def report(message):
    if _show_progress:
        print('editor dependencies: ' + message, file=sys.stderr, flush=True)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key: ' + key)
        result[key] = value
    return result


def load_json(text):
    return json.loads(text, object_pairs_hook=unique_object)


def hex_string(value, length):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{' + str(length) + '}', value) is not None


def relative_path(value):
    if not isinstance(value, str) or not value or '\\' in value or '\x00' in value:
        raise ValueError('invalid relative path')
    parts = value.split('/')
    if any(part in ('', '.', '..') for part in parts):
        raise ValueError('unsafe relative path: ' + value)
    return PurePosixPath(value)


def validate_manifest(manifest):
    if not isinstance(manifest, dict) or set(manifest) != {'schema_version', 'plugins', 'artifact'}:
        raise ValueError('invalid manifest fields')
    if type(manifest['schema_version']) is not int or manifest['schema_version'] != 1:
        raise ValueError('unsupported manifest schema')
    if not isinstance(manifest['plugins'], list) or not manifest['plugins']:
        raise ValueError('manifest plugins must be a nonempty array')
    names, repos = set(), set()
    for plugin in manifest['plugins']:
        if not isinstance(plugin, dict) or set(plugin) != {'name', 'repo', 'commit', 'url', 'sha256', 'source_sha256', 'scope'}:
            raise ValueError('invalid plugin fields')
        name = plugin['name']
        if not isinstance(name, str) or not re.fullmatch('[A-Za-z0-9][A-Za-z0-9._-]*', name):
            raise ValueError('invalid plugin name')
        if not isinstance(plugin['repo'], str) or not re.fullmatch('[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', plugin['repo']):
            raise ValueError('invalid plugin repository')
        if name in names or plugin['repo'] in repos:
            raise ValueError('duplicate plugin identity')
        if not hex_string(plugin['commit'], 40) or not hex_string(plugin['sha256'], 64) or not hex_string(plugin['source_sha256'], 64):
            raise ValueError('invalid plugin commit/checksum')
        if plugin['scope'] not in ('app', 'recording'):
            raise ValueError('invalid plugin scope')
        validate_url(plugin['url'])
        names.add(name); repos.add(plugin['repo'])
    artifact = manifest['artifact']
    fields = {'platform', 'version', 'url', 'sha256', 'binary_sha256', 'member', 'output'}
    if not isinstance(artifact, dict) or set(artifact) != fields:
        raise ValueError('invalid artifact fields')
    for key in ('platform', 'version'):
        if not isinstance(artifact[key], str) or not re.fullmatch('[A-Za-z0-9._-]+', artifact[key]):
            raise ValueError('invalid artifact ' + key)
    member = relative_path(artifact['member'])
    relative_path(artifact['output'])
    if len(member.parts) != 1 or artifact['output'] != 'plugins/markdown-preview.nvim/app/bin/' + str(member):
        raise ValueError('invalid binary output')
    if 'markdown-preview.nvim' not in names:
        raise ValueError('Preview source plugin missing')
    if not hex_string(artifact['sha256'], 64) or not hex_string(artifact['binary_sha256'], 64):
        raise ValueError('invalid binary checksum')
    validate_url(artifact['url'])
    return manifest


def validate_url(value):
    if not isinstance(value, str) or urllib.parse.urlsplit(value).scheme not in ('https', 'http', 'file'):
        raise ValueError('unsupported archive URL')


def validate_member(member):
    path = relative_path(member.name.rstrip('/') if member.isdir() else member.name)
    if not (member.isdir() or member.isfile()) or member.issparse():
        raise ValueError('unsupported archive member type: ' + member.name)
    if member.size < 0 or member.size > MAX_UNPACKED_BYTES:
        raise ValueError('archive member exceeds size limit')
    return path


def parse_receipt(text, manifest):
    receipt = load_json(text)
    if not isinstance(receipt, dict) or set(receipt) != {'schema_version', 'manifest', 'files'}:
        raise ValueError('invalid receipt fields')
    if type(receipt['schema_version']) is not int or receipt['schema_version'] != 1:
        raise ValueError('unsupported receipt schema')
    if canonical(receipt['manifest']) != canonical(manifest):
        raise ValueError('receipt manifest mismatch')
    files = receipt['files']
    if not isinstance(files, dict) or not files:
        raise ValueError('invalid receipt payload')
    for name, entry in files.items():
        relative_path(name)
        if name == 'receipt.json' or not isinstance(entry, dict) or set(entry) != {'sha256', 'executable'}:
            raise ValueError('invalid receipt file')
        if not hex_string(entry['sha256'], 64) or type(entry['executable']) is not bool:
            raise ValueError('invalid receipt file identity')
    return receipt


def compare_payloads(expected, actual):
    if expected != actual:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        changed = sorted(key for key in set(actual) & set(expected) if actual[key] != expected[key])
        raise ValueError('bundle payload mismatch: missing=%s extra=%s changed=%s' % (missing[:5], extra[:5], changed[:5]))


def digest(path):
    checksum = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(chunk)
    return checksum.hexdigest()


def payload_inventory(root, include_receipt=False):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('bundle must be a directory, not a symlink')
    result = {}
    for current, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            path = Path(current) / name
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                raise ValueError('bundle symlink forbidden: ' + str(path))
            if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
                raise ValueError('bundle special file forbidden: ' + str(path))
        for name in files:
            path = Path(current) / name
            relative = path.relative_to(root).as_posix()
            if include_receipt or relative != 'receipt.json':
                result[relative] = {'sha256': digest(path), 'executable': bool(path.stat().st_mode & 0o111)}
    return dict(sorted(result.items()))


def check_layout(root, manifest, files):
    plugins = root / 'plugins'
    if not plugins.is_dir() or {p.name for p in plugins.iterdir()} != {p['name'] for p in manifest['plugins']}:
        raise ValueError('bundle plugin directory set mismatch')
    for plugin in manifest['plugins']:
        prefix = 'plugins/' + plugin['name'] + '/'
        if not (plugins / plugin['name']).is_dir() or not any(name.startswith(prefix) for name in files):
            raise ValueError('empty/missing plugin: ' + plugin['name'])
        # Receipts are writable evidence, not an independent source of trust.
        # Bind every source file to the archive-derived inventory in the manifest.
        source = {name[len(prefix):]: entry for name, entry in files.items()
                  if name.startswith(prefix) and name != manifest['artifact']['output']}
        if hashlib.sha256(canonical(source).encode()).hexdigest() != plugin['source_sha256']:
            raise ValueError('plugin source identity mismatch: ' + plugin['name'])
    if any(not name.startswith('plugins/') for name in files):
        raise ValueError('payload outside declared plugin roots')
    artifact = manifest['artifact']
    binary = files.get(artifact['output'])
    if binary != {'sha256': artifact['binary_sha256'], 'executable': True}:
        raise ValueError('Preview binary identity mismatch')


def seal_bundle(root, manifest):
    root = Path(root)
    validate_manifest(manifest)
    files = payload_inventory(root)
    check_layout(root, manifest, files)
    receipt = {'schema_version': 1, 'manifest': manifest, 'files': files}
    path = root / 'receipt.json'
    if path.is_symlink():
        raise ValueError('receipt symlink forbidden')
    path.write_text(canonical(receipt) + '\n')
    return root


def verify_bundle(root, manifest):
    root = Path(root)
    validate_manifest(manifest)
    if (root / 'receipt.json').is_symlink():
        raise ValueError('receipt symlink forbidden')
    try:
        receipt = parse_receipt((root / 'receipt.json').read_text(), manifest)
    except OSError as error:
        raise ValueError('missing bundle receipt') from error
    actual = payload_inventory(root)
    compare_payloads(receipt['files'], actual)
    check_layout(root, manifest, actual)
    return {'schema_version': 1, 'manifest': manifest, 'files': actual}


def initialize_root(root, create):
    root = Path(os.path.abspath(root))
    if root.is_symlink():
        raise ValueError('cache root must be owned, not a symlink')
    if not root.exists() and create:
        root.mkdir(parents=True)
    if not root.is_dir():
        raise ValueError('cache root is not owned')
    marker = root / MARKER
    if not marker.exists() and create and not any(root.iterdir()):
        with marker.open('x') as stream:
            stream.write(OWNER)
    if marker.is_symlink() or not marker.is_file() or marker.read_text() != OWNER:
        raise ValueError('cache root is not app-owned: ' + str(root))
    return root


@contextlib.contextmanager
def exclusive_lease(root, create=True, timeout=TIMEOUT):
    root = initialize_root(root, create)
    fd = os.open(root / '.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        deadline = time.monotonic() + timeout
        reported_wait = False
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if not reported_wait:
                    report('Waiting for editor bundle lease; another local editor may still be running...')
                    reported_wait = True
                if time.monotonic() >= deadline:
                    raise ValueError('editor bundle lease busy; close active editors and retry')
                time.sleep(min(.05, max(0, deadline - time.monotonic())))
        yield root, fd
    finally:
        os.close(fd)


def collect_owned(root, keep=None, staging_only=False):
    removable = []
    for path in root.iterdir():
        if path == keep or path.name in (MARKER, '.lock'):
            continue
        if not (re.fullmatch('bundle-[0-9a-f]{64}', path.name) or path.name.startswith('staging-')):
            raise ValueError('unknown entry in owned cache: ' + path.name)
        if path.is_symlink() or not path.is_dir():
            raise ValueError('unexpected cache entry type: ' + path.name)
        if not staging_only or path.name.startswith('staging-'):
            removable.append(path)
    for path in removable:
        shutil.rmtree(path)


def _download_worker(record_json, output_fd, archives, timeout, max_bytes):
    """Blocking IO stays in a disposable process, including DNS and headers."""
    import signal

    record = load_json(record_json)
    timeout, max_bytes = float(timeout), int(max_bytes)
    def expired(_number, _frame):
        raise TimeoutError('archive worker total time deadline exceeded')
    # Backup for parent death: an orphaned worker must not drip indefinitely.
    # The parent's process deadline still includes worker startup and DNS.
    signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, timeout)
    try:
        with os.fdopen(int(output_fd), 'wb') as output:
            source = None
            if archives:
                candidates = [Path(archives) / (record['name'] + '-' + record['commit'] + '.tar.gz')] if 'commit' in record else []
                candidates.append(Path(archives) / Path(urllib.parse.urlsplit(record['url']).path).name)
                source = next((candidate for candidate in candidates if candidate.is_file()), None)
                if source is None:
                    raise ValueError('archive cache missing: ' + record['url'])
            opener = source.open('rb') if source else urllib.request.urlopen(record['url'], timeout=timeout)
            checksum, total = hashlib.sha256(), 0
            with opener as stream:
                while True:
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > max_bytes:
                        raise ValueError('archive size limit exceeded')
                    output.write(chunk)
                    checksum.update(chunk)
            if checksum.hexdigest() != record['sha256']:
                raise ValueError('archive checksum mismatch: ' + record['url'])
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def fetch_archive(record, destination, archives=None):
    label = (record['name'] + ' (' + record['commit'][:12] + ')') if 'commit' in record else (
        'Preview ' + record.get('version', '?') + ' (' + record.get('platform', '?') + ')')
    report(('Verifying cached archive ' if archives else 'Downloading ') + label + '...')
    # A socket timeout measures inactivity, not request duration. Isolate every
    # blocking step in a worker so trickling bodies/headers and DNS cannot keep
    # the caller past its total deadline. Cache reads use the same boundary.
    deadline = time.monotonic() + TIMEOUT
    worker = None
    succeeded = False
    communicated = False
    # Exclusively create the destination before spawning. Only this owned file
    # may be removed on failure; preexisting caller files remain untouched.
    with destination.open('xb') as output:
        try:
            worker = subprocess.Popen([
                sys.executable, '-c',
                "import runpy,sys; runpy.run_path(sys.argv[1])['_download_worker'](*sys.argv[2:])",
                str(Path(__file__).resolve()), canonical(record), str(output.fileno()),
                str(archives) if archives else '', str(TIMEOUT), str(MAX_ARCHIVE_BYTES),
            ], pass_fds=(output.fileno(),), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            try:
                _, error = worker.communicate(timeout=max(0, deadline - time.monotonic()))
                communicated = True
            except subprocess.TimeoutExpired as error:
                raise ValueError('archive total time deadline exceeded') from error
            if worker.returncode:
                raise ValueError(error.decode('utf-8', errors='replace').strip() or 'archive worker failed')
            succeeded = True
        finally:
            if worker is not None and not communicated:
                if worker.poll() is None:
                    worker.kill()
                worker.communicate()  # Reap before deleting any partially written bytes.
            if not succeeded:
                destination.unlink()


def extract_archive(archive, destination, member_name=None):
    with tarfile.open(archive, 'r:*') as stream:
        members, names, total = [], set(), 0
        for item in stream:
            name = validate_member(item)
            if str(name) in names:
                raise ValueError('duplicate archive destination: ' + str(name))
            names.add(str(name))
            total += item.size
            if len(names) > MAX_MEMBERS or total > MAX_UNPACKED_BYTES:
                raise ValueError('unpacked archive size limit exceeded')
            members.append((item, name))
        if member_name is None:
            roots = {name.parts[0] for _, name in members}
            if len(roots) != 1:
                raise ValueError('plugin archive must have one root directory')
        selected = 0
        for item, name in members:
            if member_name is not None:
                if str(name) != member_name:
                    continue
                if not item.isfile():
                    raise ValueError('binary archive member is not a file')
                path = destination
            else:
                if len(name.parts) == 1:
                    if item.isfile():
                        raise ValueError('plugin archive root is not a directory')
                    continue
                path = destination.joinpath(*name.parts[1:])
            if item.isdir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with stream.extractfile(item) as source, path.open('xb') as output:
                    shutil.copyfileobj(source, output, 1024 * 1024)
                path.chmod(0o755 if item.mode & 0o111 else 0o644)
                selected += 1
        if not selected:
            raise ValueError('archive has no requested payload')


def prepare_locked(root, manifest, archives=None):
    validate_manifest(manifest)
    identity = hashlib.sha256(canonical(manifest).encode()).hexdigest()
    final = root / ('bundle-' + identity)
    if final.exists() or final.is_symlink():
        report('Verifying cached editor bundle...')
        try:
            verify_bundle(final, manifest)
        except (ValueError, OSError) as error:
            raise ValueError('corrupt editor bundle; run repair --root ' + str(root) + ': ' + str(error)) from error
        collect_owned(root, final)
        return final
    # Interrupted stages can never be selected; only an exclusive owner collects.
    collect_owned(root, staging_only=True)
    staging = Path(tempfile.mkdtemp(prefix='staging-', dir=root))
    try:
        payload = staging / 'payload'
        payload.mkdir()
        for index, plugin in enumerate(manifest['plugins']):
            archive = staging / ('source-' + str(index) + '.tar.gz')
            fetch_archive(plugin, archive, archives)
            extract_archive(archive, payload / 'plugins' / plugin['name'])
        artifact = manifest['artifact']
        archive = staging / 'binary.tar.gz'
        fetch_archive(artifact, archive, archives)
        extract_archive(archive, payload / artifact['output'], artifact['member'])
        report('Verifying assembled editor bundle...')
        seal_bundle(payload, manifest)
        verify_bundle(payload, manifest)
        if final.exists():
            raise ValueError('bundle publication destination already exists')
        os.rename(payload, final)
        collect_owned(root, final)
        return final
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def prepare_bundle(root, manifest, archives=None, timeout=TIMEOUT):
    with exclusive_lease(root, timeout=timeout) as (owned, _):
        return prepare_locked(owned, manifest, archives)


def source_identity(archive, checksum):
    archive = Path(archive)
    if not hex_string(checksum, 64) or digest(archive) != checksum:
        raise ValueError('source archive checksum mismatch')
    with tempfile.TemporaryDirectory(prefix='parley-source-identity-') as temporary:
        source = Path(temporary) / 'source'
        extract_archive(archive, source)
        return hashlib.sha256(canonical(payload_inventory(source, include_receipt=True)).encode()).hexdigest()


def repair_bundle(root, timeout=TIMEOUT):
    with exclusive_lease(root, create=False, timeout=timeout) as (owned, _):
        collect_owned(owned)


def run_with_bundle(root, manifest, command, archives=None, timeout=TIMEOUT):
    if not command:
        raise ValueError('run requires a command after --')
    with exclusive_lease(root, timeout=timeout) as (owned, fd):
        path = prepare_locked(owned, manifest, archives)
        fcntl.flock(fd, fcntl.LOCK_SH)
        # Conversion can briefly release EX on some kernels. A waiting writer
        # may collect this version before SH succeeds; never exec stale paths.
        verify_bundle(path, manifest)
        os.set_inheritable(fd, True)
        os.environ['PARLEY_EDITOR_BUNDLE'] = str(path)
        os.environ['PARLEY_EDITOR_LEASE_FD'] = str(fd)
        report('Editor dependencies ready; starting ' + Path(command[0]).name + '.')
        os.execvp(command[0], command)


def read_manifest(args):
    report('Reading editor dependency manifest...')
    if args.manifest:
        value = load_json(Path(args.manifest).read_text())
    else:
        if not args.runtime:
            raise ValueError('--runtime or --manifest required')
        exporter = Path(args.runtime).resolve() / 'scripts/export-editor-dependencies.lua'
        proc = subprocess.run(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(exporter), args.profile, args.platform],
                              check=True, capture_output=True, text=True, timeout=TIMEOUT)
        value = load_json(proc.stdout)
    return validate_manifest(value)


def main():
    global _show_progress
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime')
    parser.add_argument('--manifest')
    parser.add_argument('--profile', choices=['app', 'recording'], default='app')
    parser.add_argument('--platform', default='auto')
    parser.add_argument('--archives')
    parser.add_argument('--lock-timeout', type=float, default=TIMEOUT)
    commands = parser.add_subparsers(dest='action', required=True)
    for name in ('prepare', 'repair', 'run'):
        command = commands.add_parser(name)
        command.add_argument('--root', required=True)
        if name == 'run': command.add_argument('command', nargs=argparse.REMAINDER)
    for name in ('verify', 'seal'):
        command = commands.add_parser(name)
        command.add_argument('--bundle', required=True)
    identity = commands.add_parser('source-identity')
    identity.add_argument('--archive', required=True)
    identity.add_argument('--sha256', required=True)
    args = parser.parse_args()
    _show_progress = args.action in ('prepare', 'run')
    try:
        if not 0 <= args.lock_timeout <= TIMEOUT:
            raise ValueError('lock timeout must be between 0 and 120 seconds')
        if args.action == 'repair':
            repair_bundle(args.root, args.lock_timeout)
            return
        if args.action == 'source-identity':
            print(source_identity(args.archive, args.sha256))
            return
        manifest = read_manifest(args)
        if args.action == 'verify':
            print(canonical(verify_bundle(Path(args.bundle), manifest)))
        elif args.action == 'seal':
            print(seal_bundle(Path(args.bundle).resolve(), manifest))
        elif args.action == 'prepare':
            path = prepare_bundle(args.root, manifest, args.archives, args.lock_timeout)
            report('Editor dependencies ready.')
            print(path)
        else:
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            run_with_bundle(args.root, manifest, command, args.archives, args.lock_timeout)
    except (ValueError, OSError, subprocess.SubprocessError, tarfile.TarError) as error:
        parser.exit(1, 'editor dependencies: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
