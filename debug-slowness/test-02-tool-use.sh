#!/bin/bash
# Test 2: Multi-turn --print with tool use (2 API calls)
# Expected: ~15s if fast, ~300s if slow
set -euo pipefail
echo "=== Test 02: --print with tool use ==="
time claude --print "read /sandbox/repo/ARCH.md and tell me the project name in one word" 2>&1
