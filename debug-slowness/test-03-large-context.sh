#!/bin/bash
# Test 3: Large system prompt (~60k chars) via --print with tool use
# Tests whether payload size causes the delay
# Expected: ~15s if fast
set -euo pipefail

BIGPROMPT=$(python3 -c '
text = "You are a helpful assistant. " * 500
text += "## Skills\n" * 100
text += "- skill: brainstorming\n" * 200
text += "- skill: test-driven-development\n" * 200
print(text[:60000])
')

echo "=== Test 03: large system prompt + tool use ==="
time echo "read /sandbox/repo/ARCH.md and say the project name" | \
    claude --print --system-prompt "$BIGPROMPT" 2>&1
