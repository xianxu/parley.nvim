#!/usr/bin/env bash
# Offline payload-shape tester for parley transcripts.
#
# Usage:
#   scripts/test-anthropic-interaction.sh <transcript.md>
#
# Env:
#   PARLEY_HARNESS_DRY_RUN=1   Skip the curl, just print the JSON payload (CI-safe)
#   PARLEY_HARNESS_AGENT=...   Override the agent (e.g. ClaudeAgentTools)
#   ANTHROPIC_API_KEY=...      Required for live mode
#
# See workshop/plans/000090-renderer-refactor.md section 6.
set -euo pipefail

TRANSCRIPT="${1:?usage: $0 <transcript.md>}"
if [ ! -f "$TRANSCRIPT" ]; then
    echo "transcript not found: $TRANSCRIPT" >&2
    exit 1
fi

# Resolve to absolute path so nvim --headless finds it regardless of cwd.
TRANSCRIPT_ABS="$(cd "$(dirname "$TRANSCRIPT")" && pwd)/$(basename "$TRANSCRIPT")"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_ROOT"
nvim --headless -u NORC \
    -c "set rtp+=$PROJECT_ROOT" \
    -c "lua package.path = package.path .. ';$PROJECT_ROOT/lua/?.lua;$PROJECT_ROOT/lua/?/init.lua;$PROJECT_ROOT/?.lua'" \
    -c "lua require('scripts.parley_harness').run('$TRANSCRIPT_ABS')" \
    -c "qa!"
