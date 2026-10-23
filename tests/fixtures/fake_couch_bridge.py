#!/usr/bin/env python3
"""Stateful protocol producer used only by Python consumer tests."""
import json
import os
from pathlib import Path
import signal
import sys
import time

sys.dont_write_bytecode = True
from fixture_watchdog import exit_with_parent

exit_with_parent()
root = Path(sys.argv[1])
mode = sys.argv[2]
root.mkdir(exist_ok=True)
(root / 'evidence').write_text('owned by producer')
(root / 'pid').write_text(str(os.getpid()))
ready = {'Version': 1, 'Namespace': str(root), 'Socket': str(root / 'ipc.sock'),
         'Environment': {'PATH': '/private/fixture/bin', 'ONLY': 'replacement'},
         'Documents': [{'ID': 'a' * 32, 'File': str(root / 'first.md')},
                       {'ID': 'b' * 32, 'File': str(root / 'first.side/second.md')}],
         'Extra': {'preserved': True}}
if mode == 'delay':
    time.sleep(2)
if mode == 'malformed':
    print('{bad', flush=True)
elif mode == 'duplicate':
    print(json.dumps(ready).replace('"Version": 1', '"Version": 1, "Version": 1'), flush=True)
elif mode == 'oversize':
    print('x' * 65537, flush=True)
elif mode == 'partial':
    sys.stdout.write('{"Version":')
    sys.stdout.flush()
elif mode == 'empty':
    sys.exit(3)
else:
    print(json.dumps(ready), flush=True)
if mode == 'early':
    sys.exit(0)
if mode == 'flood':
    for _ in range(256):
        os.write(2, b'x' * 4096)
    print('retained-root: ' + str(root), file=sys.stderr, flush=True)
    (root / 'flooded').touch()
if mode == 'second':
    print(json.dumps(ready), flush=True)
sys.stdin.buffer.read()
(root / 'eof').write_text('observed')
if mode == 'hang':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(10)
if mode == 'nonzero':
    print('retained-root: ' + str(root), file=sys.stderr, flush=True)
    sys.exit(4)
(root / 'cleaned').touch()
