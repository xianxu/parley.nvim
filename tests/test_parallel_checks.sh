#!/usr/bin/env bash
# Unit tests for scripts/parallel-checks.sh threshold logic and state file handling.
# Tests the pure logic functions (read_state, check_action, update_state) by
# sourcing the script with git commands mocked out.
#
# Usage: tests/test_parallel_checks.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib.sh"

# ── Test counters ─────────────────────────────────────────────────────────────
PASSED=0
FAILED=0
FAILURES=""

pass() { PASSED=$((PASSED + 1)); printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { FAILED=$((FAILED + 1)); FAILURES="${FAILURES}\n  ✗ $1: $2"; printf "  ${RED}✗${RESET} %s: %s\n" "$1" "$2"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc" "expected '$expected', got '$actual'"
    fi
}

# ── Test harness: load script functions with git mocked ───────────────────────
# Loads the threshold/state functions from parallel-checks.sh into a subshell
# with controllable DIFF_LINES, DIFF_FILES, and git_diff_base output.
# Args: MOCK_SHA  MOCK_LINES  MOCK_FILES  STATE_FILE_PATH  <bash code to eval>
run_with_mocks() {
    local mock_sha="$1" mock_lines="$2" mock_files="$3" state_file="$4"
    shift 4
    local code="$*"

    bash <<EOF
set -euo pipefail
source "$REPO_ROOT/scripts/lib.sh"

# Mock git commands
git_diff_base() { echo "$mock_sha"; }
measure_diff() { DIFF_LINES=$mock_lines; DIFF_FILES=$mock_files; }

# Script constants (mirroring parallel-checks.sh defaults)
THRESHOLD_LINES=400
THRESHOLD_FILES=10
GROWTH_GATE_PCT=50
FORCE_MULTIPLIER=3
STATE_FILE="$state_file"

$(declare -f read_state check_action update_state 2>/dev/null || true)

# Source just the function definitions from the script (skip main execution)
$(grep -A 100 '^read_state()' "$REPO_ROOT/scripts/parallel-checks.sh" \
    | awk '/^read_state\(\)/,/^}/' )
$(grep -A 100 '^check_action()' "$REPO_ROOT/scripts/parallel-checks.sh" \
    | awk '/^check_action\(\)/,/^}/' )
$(grep -A 100 '^update_state()' "$REPO_ROOT/scripts/parallel-checks.sh" \
    | awk '/^update_state\(\)/,/^}/' )

$code
EOF
}

# ── Temp dir for state files ──────────────────────────────────────────────────
TMPDIR_TESTS=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TESTS"' EXIT

new_state_file() { echo "$TMPDIR_TESTS/state_$$_$RANDOM"; }

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}read_state: state file parsing${RESET}\n"

# No state file → defaults to 0/0
state=$(new_state_file)
result=$(run_with_mocks "abc123" 50 3 "$state" '
    read_state
    echo "$LAST_LINES $LAST_FILES"
')
assert_eq "no state file → 0/0" "0 0" "$result"

# State file with matching SHA → reads lines and files
state=$(new_state_file)
printf 'abc123\n80\n5\n' > "$state"
result=$(run_with_mocks "abc123" 50 3 "$state" '
    read_state
    echo "$LAST_LINES $LAST_FILES"
')
assert_eq "matching SHA → reads stored values" "80 5" "$result"

# State file with different SHA → resets to 0/0
state=$(new_state_file)
printf 'old_sha\n80\n5\n' > "$state"
result=$(run_with_mocks "new_sha" 50 3 "$state" '
    read_state
    echo "$LAST_LINES $LAST_FILES"
')
assert_eq "stale SHA → resets to 0/0" "0 0" "$result"

# State file with empty lines/files fields → safe defaults
state=$(new_state_file)
printf 'abc123\n\n\n' > "$state"
result=$(run_with_mocks "abc123" 50 3 "$state" '
    read_state
    echo "$LAST_LINES $LAST_FILES"
')
assert_eq "empty fields in state file → 0/0" "0 0" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}update_state: writes correct format${RESET}\n"

state=$(new_state_file)
run_with_mocks "abc123" 75 4 "$state" 'update_state' >/dev/null
stored=$(cat "$state")
assert_eq "update_state writes SHA on line 1" "abc123" "$(sed -n '1p' "$state")"
assert_eq "update_state writes lines on line 2" "75"    "$(sed -n '2p' "$state")"
assert_eq "update_state writes files on line 3" "4"     "$(sed -n '3p' "$state")"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}check_action: absolute defaults (no prior state)${RESET}\n"

# THRESHOLD_LINES=400, THRESHOLD_FILES=10 when LAST=0
# force = 3×nag = 1200 lines / 30 files

state=$(new_state_file)

result=$(run_with_mocks "sha" 0 0 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "0 lines, 0 files → none" "none" "$result"

result=$(run_with_mocks "sha" 399 9 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "just under nag threshold → none" "none" "$result"

result=$(run_with_mocks "sha" 400 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines at nag threshold → nag" "nag" "$result"

result=$(run_with_mocks "sha" 50 10 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files at nag threshold → nag" "nag" "$result"

result=$(run_with_mocks "sha" 1200 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines at force threshold (3×400) → force" "force" "$result"

result=$(run_with_mocks "sha" 50 30 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files at force threshold (3×10) → force" "force" "$result"

result=$(run_with_mocks "sha" 1199 29 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "just under force threshold → nag" "nag" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}check_action: growth from prior state${RESET}\n"

# LAST=100 lines, 4 files → nag at 150/6, force at 450/18

state=$(new_state_file)
printf 'sha\n100\n4\n' > "$state"

result=$(run_with_mocks "sha" 149 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "below nag threshold → none" "none" "$result"

result=$(run_with_mocks "sha" 150 3 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines at nag threshold (100+50%) → nag" "nag" "$result"

result=$(run_with_mocks "sha" 100 6 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files at nag threshold (4+50%=6) → nag" "nag" "$result"

result=$(run_with_mocks "sha" 450 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines at force threshold (3×150) → force" "force" "$result"

result=$(run_with_mocks "sha" 100 18 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files at force threshold (3×6) → force" "force" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}check_action: growth floor (minimum +1)${RESET}\n"

# LAST=1 line, 1 file — 50% of 1 = 0 (integer), floor ensures nag at 2 not 1

state=$(new_state_file)
printf 'sha\n1\n1\n' > "$state"

result=$(run_with_mocks "sha" 1 1 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "at baseline (1/1) → none" "none" "$result"

result=$(run_with_mocks "sha" 2 1 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines cross floor nag threshold (1+1=2) → nag" "nag" "$result"

result=$(run_with_mocks "sha" 1 2 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files cross floor nag threshold (1+1=2) → nag" "nag" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}check_action: stale SHA resets to absolute defaults${RESET}\n"

state=$(new_state_file)
printf 'old_sha\n50\n2\n' > "$state"  # low thresholds if respected

# With stale SHA, falls back to THRESHOLD_LINES=400/THRESHOLD_FILES=10
result=$(run_with_mocks "new_sha" 100 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "stale SHA → uses absolute defaults, 100/5 is none" "none" "$result"

result=$(run_with_mocks "new_sha" 400 5 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "stale SHA → uses absolute defaults, 400 lines nags" "nag" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${CYAN}${BOLD}check_action: OR logic (lines OR files triggers)${RESET}\n"

state=$(new_state_file)  # no prior state → absolute defaults (400/10)

result=$(run_with_mocks "sha" 500 1 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "lines alone can trigger nag (500 lines, 1 file)" "nag" "$result"

result=$(run_with_mocks "sha" 10 11 "$state" 'check_action; echo $HOOK_ACTION')
assert_eq "files alone can trigger nag (10 lines, 11 files)" "nag" "$result"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n"
if [[ $FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}All $PASSED tests passed.${RESET}\n\n"
else
    printf "${RED}${BOLD}$FAILED failed, $PASSED passed.${RESET}\n"
    printf "$FAILURES\n\n"
    exit 1
fi
