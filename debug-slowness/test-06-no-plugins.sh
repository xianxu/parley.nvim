#!/bin/bash
# Test 6: Interactive session with skills/plugins disabled
# Tests whether superpowers plugin loading causes the delay
# Expected: fast if plugin system is the cause
set -euo pipefail
cd /sandbox/repo

echo "=== Test 06: interactive, no slash commands ==="
time echo "read ARCH.md and say project name in one word" | \
    claude --permission-mode bypassPermissions --disable-slash-commands 2>&1 | tail -10
