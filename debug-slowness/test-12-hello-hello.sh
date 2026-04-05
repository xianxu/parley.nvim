#!/bin/bash
# Test 12: Minimal repro — two consecutive messages in the same session
# 1st message via --print to get session ID
# 2nd message via --resume --print to reuse the session
#
# If the bug repros, the 2nd message will take ~290s.
# If not, it should take ~5-10s.
set -euo pipefail
cd /sandbox/repo

echo "=== Test 12: hello → hello (same session, --print + --resume) ==="

echo "--- 1st message ---"
SESSION_ID=$(claude --print --output-format json -p "hello" --permission-mode bypassPermissions 2>/dev/null \
    | python3 -c 'import sys,json; [print(json.loads(l).get("session_id","")) for l in sys.stdin if "session_id" in l]' \
    | head -1)
echo "Session ID: $SESSION_ID"

echo "--- 2nd message (should be fast if no bug) ---"
time claude --print --resume "$SESSION_ID" -p "hello again" --permission-mode bypassPermissions 2>&1

echo "=== Done ==="
