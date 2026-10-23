#!/usr/bin/env python3
"""Serialize a checkout's test commands; the inherited flock survives exec (#409)."""
import argparse
import fcntl
import os
import pathlib
import sys
import stat
import tempfile
import subprocess
from itertools import islice

FD_ENV = 'PARLEY_TEST_LEASE_FD'
CONTEXT_ENV = 'PARLEY_TEST_PROCESS_DIR'
MAX_RUNS = 256
MAX_SCOPES = 64


def registry_base(root):
    """Keep Git checkout churn in its own metadata, outside linked worktrees."""
    root = pathlib.Path(root).resolve()
    if not os.path.lexists(root / '.git'):
        return root / '.test-processes'  # contributor archives / isolated fixtures
    env = dict(os.environ)
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR'):
        env.pop(name, None)
    result = subprocess.run(['git', '-C', str(root), 'rev-parse', '--absolute-git-dir', '--show-toplevel'],
                            capture_output=True, text=True, timeout=5, env=env)
    values = result.stdout.splitlines()
    if result.returncode or len(values) != 2 or not pathlib.Path(values[0]).is_absolute() \
            or pathlib.Path(values[1]).resolve() != root:
        raise ValueError('test process registry cannot resolve checkout Git metadata')
    gitdir = pathlib.Path(values[0]).resolve()
    if not owned_directory(gitdir):
        raise ValueError('unowned checkout Git metadata')
    return gitdir / 'parley-test-processes'


def owned_directory(path):
    info = path.lstat()
    return stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid() and not info.st_mode & 0o022


def run_context(root, reuse=False):
    """Retain bounded birth evidence outside the scratch cleaned by make."""
    base = registry_base(root)
    if not reuse:
        base.mkdir(mode=0o700, exist_ok=True)
    if not owned_directory(base):
        raise ValueError('unowned test process registry')
    if reuse:
        value = os.environ.get(CONTEXT_ENV)
        context = pathlib.Path(value) if value else None
        if context is None or context.parent != base or context.name == '..':
            raise ValueError('missing or foreign inherited test process context')
        if not owned_directory(context):
            raise ValueError('invalid inherited test process context')
        return str(context)
    # Only empty owned directories can retire here. Pending/corrupt evidence
    # belongs to the independent census, never to scratch preparation.
    runs = list(islice(base.iterdir(), MAX_RUNS + 1))
    if len(runs) > MAX_RUNS:
        raise ValueError('retained test run limit reached; inspect unresolved census evidence')
    for run in runs:
        if not owned_directory(run):
            continue
        scopes = list(islice(run.iterdir(), MAX_SCOPES + 1))
        if len(scopes) > MAX_SCOPES:
            continue
        for scope in scopes:
            if not owned_directory(scope):
                continue
            try:
                scope.rmdir()
            except OSError:
                pass
        try:
            run.rmdir()
        except OSError:
            pass
    if sum(1 for _ in base.iterdir()) >= MAX_RUNS:
        raise ValueError('retained test run limit reached; inspect unresolved census evidence')
    context = tempfile.mkdtemp(prefix='run-', dir=base)
    os.environ[CONTEXT_ENV] = context
    return context


def inherited(root):
    value = os.environ.get(FD_ENV)
    if value is None:
        return None
    try:
        fd = int(value)
        held = os.fstat(fd)
    except (ValueError, OSError) as exc:
        raise ValueError('invalid inherited test lease descriptor') from exc
    path = pathlib.Path(root).resolve() / '.test-run.lock'
    if not path.exists() or not os.path.samestat(held, path.stat()):
        return None  # A nested command in a different checkout takes its own lease.
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    return fd


def enter(root):
    fd = inherited(root)
    if fd is not None:
        return fd
    path = pathlib.Path(root).resolve() / '.test-run.lock'
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        try:
            holder = str(int(os.pread(fd, 32, 0).strip()))
        except ValueError:
            holder = 'unknown'
        print(f'test lease: waiting for pid={holder} in {path.parent}', file=sys.stderr, flush=True)
        fcntl.flock(fd, fcntl.LOCK_EX)
    os.ftruncate(fd, 0)
    os.write(fd, f'{os.getpid()}\n'.encode())
    os.set_inheritable(fd, True)
    os.environ[FD_ENV] = str(fd)
    return fd


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--require', action='store_true')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.require:
        if inherited(args.root) is None:
            parser.error('test lease required; enter through a public test target')
        run_context(args.root, reuse=True)
        return
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required after --')
    reuse = inherited(args.root) is not None
    enter(args.root)
    run_context(args.root, reuse)
    os.execvp(command[0], command)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        sys.exit(f'test lease: {exc}')
    except KeyboardInterrupt:
        sys.exit(130)
