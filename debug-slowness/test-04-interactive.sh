#!/bin/bash
# Test 4: Full interactive session (the slow path)
# This loads superpowers skills, CLAUDE.md, AGENTS.md, project context
# Expected: ~293s per API call if bug repros
set -euo pipefail
cd /sandbox/repo

echo "=== Test 04: interactive session ==="
echo "Piping a simple tool-use prompt into interactive claude..."
echo "Watch /var/log/openshell.*.log and the jsonl session log for timing."
time echo "read ARCH.md and say project name in one word" | \
    claude --permission-mode bypassPermissions 2>&1 | tail -10
