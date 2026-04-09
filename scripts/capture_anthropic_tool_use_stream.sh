#!/usr/bin/env bash
# Capture a real Anthropic SSE tool_use stream for M2 Task 2.4 fixtures.
#
# Usage:
#
#     export ANTHROPIC_API_KEY=sk-...
#     bash scripts/capture_anthropic_tool_use_stream.sh
#
# Produces:
#
#     tests/fixtures/anthropic_tool_use_stream_real.jsonl
#
# The request is at tests/fixtures/anthropic_tool_use_request.json and
# asks Claude to call read_file on lua/parley/init.lua. The tools list
# contains read_file and list_dir so the model has something to choose
# from without too much freedom. The prompt is deliberately direct so
# the model tends to call a tool rather than guess.
#
# After capture, tests/unit/anthropic_tool_decode_spec.lua gains a
# "real data" describe block that runs the same decoder against this
# file to lock in doc-vs-reality parity. If the real data diverges
# from synthetic, real data wins and the decoder is updated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REQUEST_FILE="$REPO_ROOT/tests/fixtures/anthropic_tool_use_request.json"
OUTPUT_FILE="$REPO_ROOT/tests/fixtures/anthropic_tool_use_stream_real.jsonl"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Error: ANTHROPIC_API_KEY is not set." >&2
    exit 1
fi

if [[ ! -f "$REQUEST_FILE" ]]; then
    echo "Error: request fixture missing: $REQUEST_FILE" >&2
    exit 1
fi

echo "→ POSTing to https://api.anthropic.com/v1/messages (streaming)"
echo "→ Request:  $REQUEST_FILE"
echo "→ Capture:  $OUTPUT_FILE"
echo ""

# -N disables output buffering so we see the stream as it arrives.
# --no-buffer is the long form and makes the intent explicit.
# -s quiets curl's own progress meter (we want only the SSE body).
# -S still shows errors on failure.
curl --silent --show-error --no-buffer \
    -X POST "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data-binary "@$REQUEST_FILE" \
    | tee "$OUTPUT_FILE"

echo ""
echo ""
echo "→ Capture complete: $(wc -l < "$OUTPUT_FILE") lines"
echo "→ Sanity-check tool_use events:"
grep -c '"type":"tool_use"' "$OUTPUT_FILE" 2>/dev/null \
    && echo "   (found tool_use content_block_start events)" \
    || echo "   WARNING: no tool_use events found — the model may have responded with text instead of calling a tool. Try a more explicit prompt."
