#!/bin/bash
# Test 7: Concurrent API connections through proxy
# Tests whether connection pooling or concurrent requests cause issues
# Claude Code opens multiple connections (API + telemetry + update check)
set -euo pipefail

echo "=== Test 07: concurrent connections ==="
echo "Launching 3 parallel claude --print calls..."

time (
    claude --print "say 1" &
    claude --print "say 2" &
    claude --print "say 3" &
    wait
) 2>&1
echo ""
echo "If any took >>10s, concurrent connections may be the issue."
