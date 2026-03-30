#!/usr/bin/env bash
# Integration tests for agent CLI assumptions.
# Validates that the CLI tools (claude, codex) behave as our scripts expect:
#   - flag combinations that work
#   - output formats and structure
#   - stream-json event schema
#   - jq extraction patterns we rely on
#
# Assumes claude CLI is available. Codex/gemini tests skipped if not installed.
# Usage: tests/test_agents.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

# ── Test counters ────────────────────────────────────────────────────────────
PASSED=0
FAILED=0
SKIPPED=0
FAILURES=""

pass() { PASSED=$((PASSED + 1)); printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { FAILED=$((FAILED + 1)); FAILURES="${FAILURES}\n  ✗ $1: $2"; printf "  ${RED}✗${RESET} %s: %s\n" "$1" "$2"; }
skip() { SKIPPED=$((SKIPPED + 1)); printf "  ${YELLOW}⊘${RESET} %s (skipped: %s)\n" "$1" "$2"; }

# ── 1. claude -p basics ─────────────────────────────────────────────────────
# We rely on `claude -p` to accept a prompt and return text output to stdout.
printf "\n${CYAN}${BOLD}claude -p basics${RESET}\n"

if ! command -v claude &>/dev/null; then
    printf "  ${RED}claude CLI not found — cannot run tests${RESET}\n"
    exit 1
fi

# 1a. -p returns output on stdout (our non-streaming path)
output=$(claude -p "Reply with exactly: PING" 2>/dev/null) || true
if [[ "$output" == *"PING"* ]]; then
    pass "claude -p returns text on stdout"
else
    fail "claude -p stdout" "expected PING in output, got: ${output:0:200}"
fi

# 1b. --permission-mode bypassPermissions works (needed for unattended checks)
output=$(claude -p --permission-mode bypassPermissions \
    "Reply with exactly: PERM_OK" 2>/dev/null) || true
if [[ "$output" == *"PERM_OK"* ]]; then
    pass "claude -p accepts --permission-mode bypassPermissions"
else
    fail "claude --permission-mode" "agent failed with bypassPermissions: ${output:0:200}"
fi

# 1c. --allowedTools works with --permission-mode (both required together)
output=$(claude -p \
    --allowedTools 'Read,Grep' \
    --permission-mode bypassPermissions \
    "Reply with exactly: TOOLS_OK" 2>/dev/null) || true
if [[ "$output" == *"TOOLS_OK"* ]]; then
    pass "claude -p accepts --allowedTools (with --permission-mode)"
else
    fail "claude --allowedTools" "agent failed: ${output:0:200}"
fi

# 1d. All flags together (the exact combo our scripts use)
output=$(claude -p \
    --allowedTools 'Read,Grep,Glob,Bash' \
    --permission-mode bypassPermissions \
    "Reply with exactly: COMBO_OK" 2>/dev/null) || true
if [[ "$output" == *"COMBO_OK"* ]]; then
    pass "claude -p with all non-streaming flags"
else
    fail "claude combined flags" "got: ${output:0:200}"
fi

# ── 2. claude stream-json output ────────────────────────────────────────────
# Our streaming progress display parses stream-json events with jq.
# These tests verify the event schema matches what we expect.
printf "\n${CYAN}${BOLD}claude stream-json output${RESET}\n"

if ! command -v jq &>/dev/null; then
    skip "stream-json tests" "jq not available"
else
    # 2a. --verbose --output-format stream-json produces output (the bug we fixed)
    events=$(claude -p \
        --allowedTools 'Read,Grep,Glob,Bash' \
        --permission-mode bypassPermissions \
        --verbose --output-format stream-json \
        "Reply with exactly: STREAM_OK" 2>/dev/null) || true
    if [[ -n "$events" ]]; then
        pass "stream-json produces output (--verbose required)"
    else
        fail "stream-json output" "empty output — does claude require --verbose for stream-json?"
    fi

    # 2b. Output contains a 'result' event (we extract final text from this)
    result_count=$(echo "$events" | jq -r 'select(.type == "result") | .type' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$result_count" -ge 1 ]]; then
        pass "stream-json has result event with .type == 'result'"
    else
        fail "result event" "no event with .type == 'result' found"
    fi

    # 2c. Result event has .result field with the response text
    result_text=$(echo "$events" | jq -r 'select(.type == "result") | .result // empty' 2>/dev/null) || true
    if [[ "$result_text" == *"STREAM_OK"* ]]; then
        pass "result event .result contains response text"
    else
        fail "result .result field" "expected STREAM_OK, got: ${result_text:0:200}"
    fi

    # 2d. Stream contains 'assistant' events (we parse these for tool-call progress)
    asst_count=$(echo "$events" | jq -r 'select(.type == "assistant") | .type' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$asst_count" -ge 1 ]]; then
        pass "stream-json has assistant events"
    else
        fail "assistant events" "no .type == 'assistant' events"
    fi

    # 2e. Each line is valid JSON (our while-read loop parses line by line)
    bad_lines=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        echo "$line" | jq empty 2>/dev/null || bad_lines=$((bad_lines + 1))
    done <<< "$events"
    if [[ "$bad_lines" -eq 0 ]]; then
        pass "every stream-json line is valid JSON"
    else
        fail "stream-json line validity" "$bad_lines non-JSON lines found"
    fi

    # 2f. When agent uses a tool, assistant event has .message.content[].type == "tool_use"
    #     with .name and .input fields (we display these as progress)
    events_with_tool=$(claude -p \
        --allowedTools 'Bash' \
        --permission-mode bypassPermissions \
        --verbose --output-format stream-json \
        "Run: echo TOOL_TEST" 2>/dev/null) || true
    tool_name=$(echo "$events_with_tool" | jq -r '
        select(.type == "assistant")
        | [.message.content[] | select(.type == "tool_use") | .name]
        | last // empty
    ' 2>/dev/null | grep -v '^$' | head -1) || true
    if [[ -n "$tool_name" ]]; then
        pass "tool_use events have .name (got: $tool_name)"
    else
        # Tool use progress is nice-to-have, not critical
        skip "tool_use .name extraction" "agent may not have used a tool"
    fi

    # 2g. Tool input has the fields we try to extract for progress hints
    #     (.file_path, .command, .pattern, .path)
    tool_input=$(echo "$events_with_tool" | jq -r '
        select(.type == "assistant")
        | [.message.content[] | select(.type == "tool_use")]
        | last
        | .input
        | (.file_path // .command // .pattern // .path // empty)
    ' 2>/dev/null | grep -v '^$' | head -1) || true
    if [[ -n "$tool_input" ]]; then
        pass "tool_use .input has extractable hint (got: ${tool_input:0:60})"
    else
        skip "tool_use .input hint" "no extractable input field"
    fi
fi

# ── 3. codex CLI assumptions ────────────────────────────────────────────────
printf "\n${CYAN}${BOLD}codex CLI${RESET}\n"

if command -v codex &>/dev/null; then
    # 3a. codex exec accepts a prompt and returns output
    output=$(codex exec "Reply with exactly: CODEX_OK" 2>/dev/null) || true
    if [[ "$output" == *"CODEX_OK"* ]]; then
        pass "codex exec returns text output"
    else
        fail "codex exec" "expected CODEX_OK, got: ${output:0:200}"
    fi
else
    skip "codex exec" "codex CLI not found"
fi

# ── 4. Output classification (lib.sh) ───────────────────────────────────────
# Our scripts use is_clean_check_output to decide ✓ vs ✗ display.
# These test the patterns we tell agents to use in their responses.
printf "\n${CYAN}${BOLD}Output classification patterns${RESET}\n"

# Clean patterns (agent says everything is fine)
for phrase in \
    "No DRY violations found." \
    "No PURE violations found." \
    "All tests pass." \
    "No changes needed." \
    "Everything is in sync."; do
    if is_clean_check_output "$phrase"; then
        pass "clean: '$phrase'"
    else
        fail "clean pattern" "'$phrase' should be detected as clean"
    fi
done

# Not clean (violations found or empty)
if ! is_clean_check_output ""; then
    pass "empty output is NOT clean (agent likely failed)"
else
    fail "empty output" "should not be clean"
fi

if ! is_clean_check_output "Found 3 DRY violations in lua/parley/init.lua"; then
    pass "violation text is NOT clean"
else
    fail "violation detection" "should not be clean"
fi

# Info pattern
if is_info_check_output "REMINDER: check lessons"; then
    pass "REMINDER is info output"
else
    fail "reminder detection" "should be info"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}━━━ Results ━━━${RESET}\n"
printf "  ${GREEN}%d passed${RESET}, ${RED}%d failed${RESET}, ${YELLOW}%d skipped${RESET}\n" "$PASSED" "$FAILED" "$SKIPPED"
if [[ -n "$FAILURES" ]]; then
    printf "\n${RED}${BOLD}Failures:${RESET}${FAILURES}\n"
fi
printf "\n"

[[ "$FAILED" -eq 0 ]]
