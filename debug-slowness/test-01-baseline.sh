#!/bin/bash
# Test 1: Single-turn --print, no tools (fast baseline)
# Expected: ~8s
set -euo pipefail
echo "=== Test 01: --print baseline ==="
time claude --print "respond with just the word pong" 2>&1
