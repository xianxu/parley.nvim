#!/bin/bash
# Test 11: Interactive session with telemetry fully blocked
# Add datadoghq.com to no_proxy so connections fail immediately
# instead of going through proxy and getting denied (which may block)
set -euo pipefail
cd /sandbox/repo

echo "=== Test 11: interactive with datadoghq in no_proxy ==="
export no_proxy="127.0.0.1,localhost,::1,http-intake.logs.us5.datadoghq.com"
export NO_PROXY="$no_proxy"
export DO_NOT_TRACK=1
time bash -c 'echo "read ARCH.md and STYLE.md and TOOLING.md, say project name in one word" | \
    claude --permission-mode bypassPermissions 2>&1 | tail -10'
