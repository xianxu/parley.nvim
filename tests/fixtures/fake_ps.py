#!/usr/bin/env python3
"""Explicit isolated state directory supplies one native ps snapshot.

snapshot.json: {rows: {PID: start}, stdout?, code?, delay_ms?}. requests.jsonl
records argv/locale/child PID before sleeping; no host process table is read.
"""
import json
import os
from pathlib import Path
import sys
import time

sys.dont_write_bytecode = True
from fixture_watchdog import exit_with_parent

exit_with_parent()
root = Path(os.environ['PARLEY_FAKE_PS_STATE'])
snapshot = json.loads((root / 'snapshot.json').read_text())
with (root / 'requests.jsonl').open('a') as stream:
    stream.write(json.dumps({'argv': sys.argv[1:], 'locale': os.environ.get('LC_ALL'), 'pid': os.getpid()}) + '\n')
    stream.flush()
time.sleep(snapshot.get('delay_ms', 0) / 1000)
if 'stdout' in snapshot:
    sys.stdout.write(snapshot['stdout'])
else:
    requested = sys.argv[sys.argv.index('-p') + 1].split(',')
    for pid in requested:
        if pid in snapshot.get('rows', {}):
            print(pid, snapshot['rows'][pid])
sys.stdout.flush()
sys.exit(snapshot.get('code', 0))
