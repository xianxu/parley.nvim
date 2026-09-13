#!/usr/bin/env python3
"""Disposable guest only; verifies stopped ownership before removing four roots."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

home = Path.home()
work = home / '.parley-acceptance'
stop = json.loads((work / 'stop.json').read_text())
roots = {'config': home / '.config/parley', 'data': home / '.local/share/parley',
         'state': home / '.local/state/parley', 'cache': home / '.cache/parley'}
assert stop.get('stopped') is True, 'owned proxy was not stopped'
assert stop['roots'] == {key: str(path) for key, path in roots.items()}, 'unexpected profile roots'
assert stop['config_path'].startswith(str(roots['data']) + '/'), 'proxy config escaped profile'


def no_proxy():
    result = subprocess.run(['ps', 'ax', '-o', 'command='], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, 'process table unavailable'
    needle = '-config ' + stop['config_path']
    for row in result.stdout.splitlines():
        if needle in row:
            tail = row.split(needle, 1)[1]
            assert tail and not tail.startswith(' '), 'owned proxy remains'


def decoy_unchanged():
    expected = (work / 'decoy.sha').read_text().split()[0]
    actual = hashlib.sha256((home / '.config/nvim/init.lua').read_bytes()).hexdigest()
    assert actual == expected, 'decoy config changed'


no_proxy()
decoy_unchanged()
result = subprocess.run(['brew', 'uninstall', 'parley'], capture_output=True, timeout=900)
assert result.returncode == 0, 'brew uninstall failed'
result = subprocess.run(['brew', 'list', '--versions', 'parley'], capture_output=True, timeout=30)
assert result.returncode != 0 and not result.stdout.strip(), 'package remains installed'
for path in roots.values():
    # Parent/profile symlinks may lead outside the disposable profile boundary.
    assert path.resolve() == path and not path.is_symlink(), 'unsafe profile path'
    if path.exists():
        shutil.rmtree(path)
    assert not path.exists(), 'profile root remains'
no_proxy()
decoy_unchanged()
evidence = {'status': 'passed', 'package_removed': True, 'profile_roots_removed': sorted(roots),
            'owned_proxy_absent': True, 'decoy_unchanged': True}
(work / 'uninstall.json').write_text(json.dumps(evidence) + '\n')
