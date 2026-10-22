#!/usr/bin/env python3
"""Serialize a checkout's test commands; the inherited flock survives exec (#409)."""
import argparse
import fcntl
import os
import pathlib
import sys

FD_ENV = 'PARLEY_TEST_LEASE_FD'


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
        return
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required after --')
    enter(args.root)
    os.execvp(command[0], command)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        sys.exit(f'test lease: {exc}')
    except KeyboardInterrupt:
        sys.exit(130)
