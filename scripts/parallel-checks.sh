#!/usr/bin/env bash
# Parallel constitution check runner.
# Runs checks in groups: parallel within a group, sequential across groups.
#
# Usage:
#   scripts/parallel-checks.sh                  # interactive (delegates to pre-merge-checks.sh)
#   scripts/parallel-checks.sh --no-commit      # report-only mode, no user prompts
#   scripts/parallel-checks.sh --hook-gate      # threshold check + no-commit + context assembly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# ── Check groups ─────────────────────────────────────────────────────────────
# Each line is a sequential group (checks that may modify the same files).
# Groups themselves run in parallel since they touch different file sets.
CHECK_GROUPS=(
    "dry pure"
    "test"
    "specs"
    "plan"
    "lessons"
)
ALL_CHECKS=(dry pure test specs plan lessons)

# ── Threshold configuration ──────────────────────────────────────────────────
THRESHOLD_LINES=400
THRESHOLD_FILES=10
GROWTH_GATE_PCT=50
STATE_FILE=".claude/constitution-check-state"
LOCK_FILE="/tmp/parallel-checks-$(pwd | md5sum | cut -c1-8).lock"

# ── TTY detection ────────────────────────────────────────────────────────────
IS_TTY=false
if [[ -t 2 ]]; then IS_TTY=true; fi

progress() {
    if "$IS_TTY"; then
        printf "\r\033[K  ${YELLOW}⟳${RESET} %s" "$*" >&2
    else
        printf "  > %s\n" "$*" >&2
    fi
}

progress_done() {
    if "$IS_TTY"; then
        printf "\r\033[K  ${GREEN}✓${RESET} %s\n" "$*" >&2
    else
        printf "  ✓ %s\n" "$*" >&2
    fi
}

# ── Threshold gate ───────────────────────────────────────────────────────────
measure_diff() {
    local base
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [[ "$branch" == "main" ]]; then
        base=$(git rev-parse origin/main 2>/dev/null || echo "HEAD~10")
    else
        base=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~10")
    fi

    DIFF_LINES=$(git diff "$base" --numstat -- ':!issues/' ':!history/' 2>/dev/null \
        | awk '{s+=$1+$2} END {print s+0}')
    DIFF_FILES=$(git diff "$base" --name-only -- ':!issues/' ':!history/' 2>/dev/null | wc -l | tr -d ' ')
}

should_run_checks() {
    measure_diff

    # Absolute threshold
    if [[ "$DIFF_FILES" -lt "$THRESHOLD_FILES" && "$DIFF_LINES" -lt "$THRESHOLD_LINES" ]]; then
        return 1
    fi

    # Growth gate: only re-fire if diff grew 20%+ since last check
    if [[ -f "$STATE_FILE" ]]; then
        local last_lines
        last_lines=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        local gate=$(( last_lines + last_lines * GROWTH_GATE_PCT / 100 ))
        if [[ "$DIFF_LINES" -le "$gate" ]]; then
            return 1
        fi
    fi

    return 0
}

update_state() {
    measure_diff
    printf '%d' "$DIFF_LINES" > "$STATE_FILE"
}

# ── Run a single check, capturing output ─────────────────────────────────────
run_check_captured() {
    local name="$1" outdir="$2"
    local rc=0
    CHECK_NO_COMMIT="${NO_COMMIT:-0}" "$SCRIPT_DIR/pre-merge-checks.sh" "$name" \
        >"$outdir/$name.out" 2>"$outdir/$name.err" || rc=$?
    printf '%d' "$rc" > "$outdir/$name.rc"
}

# ── Run a sequential group (checks that may touch same files) ────────────────
run_sequential_group() {
    local outdir="$1"; shift
    for check in "$@"; do
        progress "running $check..."
        run_check_captured "$check" "$outdir"
        local rc
        rc=$(cat "$outdir/$check.rc" 2>/dev/null || echo 0)
        if [[ "$rc" == "0" ]]; then
            progress_done "$check — clean"
        else
            progress_done "$check — violations found"
        fi
    done
}

# ── Assemble context from check outputs ──────────────────────────────────────
assemble_context() {
    local outdir="$1"
    local found=0
    for name in "${ALL_CHECKS[@]}"; do
        local rc_file="$outdir/$name.rc"
        [[ -f "$rc_file" ]] || continue
        local rc
        rc=$(cat "$rc_file")
        if [[ "$rc" != "0" ]]; then
            found=1
            printf '=== Constitution Check: %s ===\n' "$name"
            cat "$outdir/$name.out"
            printf '\n'
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        : # Silent-unless-violated: no output = no context injection
    fi
}

# ── Run all groups in parallel, checks within each group sequentially ────────
run_all_groups() {
    local outdir="$1"
    local pids=()
    for group in "${CHECK_GROUPS[@]}"; do
        # shellcheck disable=SC2086
        run_sequential_group "$outdir" $group &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local no_commit=0
    local hook_gate=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-commit) no_commit=1; shift ;;
            --hook-gate) hook_gate=1; no_commit=1; shift ;;
            *) printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2; return 1 ;;
        esac
    done

    # Hook gate mode: check threshold first
    if [[ "$hook_gate" -eq 1 ]]; then
        # Lockfile: prevent concurrent runs
        exec 9>"$LOCK_FILE"
        if ! flock -n 9; then
            exit 0  # another run in progress, skip silently
        fi

        if ! should_run_checks; then
            exit 0  # below threshold, silent
        fi
    fi

    # Interactive mode: delegate to existing script (it has its own menu + accept/discard)
    if [[ "$no_commit" -eq 0 ]]; then
        exec "$SCRIPT_DIR/pre-merge-checks.sh"
    fi

    export NO_COMMIT=1

    # Create temp dir for captured outputs
    OUTDIR=$(mktemp -d)
    trap 'rm -rf "$OUTDIR"' EXIT

    printf "\n${CYAN}${BOLD}Constitution checks${RESET}" >&2
    measure_diff
    printf " (%s files, ~%s lines changed)\n" "$DIFF_FILES" "$DIFF_LINES" >&2

    run_all_groups "$OUTDIR"
    assemble_context "$OUTDIR"

    if [[ "$hook_gate" -eq 1 ]]; then
        update_state
    fi

    printf "\n${GREEN}${BOLD}All constitution checks complete.${RESET}\n" >&2
}

main "$@"
