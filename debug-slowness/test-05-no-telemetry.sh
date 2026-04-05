#!/bin/bash
# Test 5: Interactive session with telemetry disabled
# Tests whether blocked datadoghq.com connections cause the delay
# Expected: fast if telemetry is the cause
set -euo pipefail
cd /sandbox/repo

echo "=== Test 05: interactive, DO_NOT_TRACK=1 ==="
time DO_NOT_TRACK=1 bash -c 'echo "read ARCH.md and say project name in one word" | \
    claude --permission-mode bypassPermissions 2>&1 | tail -10'
