#!/usr/bin/env python3
"""Import the real orchestrator with a deterministic test-only capacity probe."""
import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
import sys

sys.dont_write_bytecode = True
source = Path(__file__).resolve().parents[2] / 'scripts/test-parley-vm.py'
spec = importlib.util.spec_from_file_location('packaging_vm', source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
try:
    sys.exit(module.main(disk_usage=lambda _: SimpleNamespace(
        free=int(os.environ.get('FAKE_DISK_FREE_BYTES', str(120 * 1024 ** 3))))))
except Exception as error:
    print('VM acceptance failed:', type(error).__name__, file=sys.stderr)
    sys.exit(1)
