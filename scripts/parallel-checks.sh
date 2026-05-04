#!/usr/bin/env bash
# Parallel constitution check runner.
# In audit mode, checks run in parallel with a concurrency limit (read-only agents).
# Set MAX_PARALLEL_CHECKS to control concurrency (default: 3).
# specs is the only check that may write files (documentation updates).
#
# Usage:
#   scripts/parallel-checks.sh                  # interactive (delegates to pre-merge-checks.sh)
#   scripts/parallel-checks.sh --audit          # all parallel, read-only, report context
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Shared helpers ────────────────────────────────────────────────────────────
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ALL_CHECKS=(dry pure specs plan lessons)

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

# ── Diff measurement ─────────────────────────────────────────────────────────
measure_diff() {
    local base
    base=$(git_diff_base)
    DIFF_LINES=$(git diff "$base" --numstat -- ":!${WF_ISSUES_DIR:-issues}/" ":!${WF_HISTORY_DIR:-history}/" 2>/dev/null \
        | awk '{s+=$1+$2} END {print s+0}')
    DIFF_FILES=$(git diff "$base" --name-only -- ":!${WF_ISSUES_DIR:-issues}/" ":!${WF_HISTORY_DIR:-history}/" 2>/dev/null | wc -l | tr -d ' ')
}

# ── Run a single check, capturing output ─────────────────────────────────────
# Read-only tools for most checks; write tools only for specs.
run_check_captured() {
    trap - EXIT  # Don't inherit parent's cleanup trap in background subshells
    local name="$1" outdir="$2"
    local rc=0
    local tools="Read,Grep,Glob,Bash"
    if [[ "$name" == "specs" ]]; then
        tools="Edit,Read,Write,Grep,Glob,Bash"
    fi
    local timeout_secs="${CHECK_TIMEOUT:-300}"
    if command -v timeout &>/dev/null; then
        timeout "$timeout_secs" env \
            ALLOWED_TOOLS="$tools" CHECK_NO_COMMIT=1 \
            "$SCRIPT_DIR/pre-merge-checks.sh" "$name" \
            < /dev/null >"$outdir/$name.out" 2>"$outdir/$name.err" || rc=$?
    else
        # macOS: no GNU timeout — use perl alarm as fallback
        perl -e 'alarm shift; exec @ARGV' "$timeout_secs" env \
            ALLOWED_TOOLS="$tools" CHECK_NO_COMMIT=1 \
            "$SCRIPT_DIR/pre-merge-checks.sh" "$name" \
            < /dev/null >"$outdir/$name.out" 2>"$outdir/$name.err" || rc=$?
    fi
    printf '%d' "$rc" > "$outdir/$name.rc"
}

# ── Assemble context from check outputs ──────────────────────────────────────
# Prints results and sets HAS_FAILURES=1 if any check has violations.
assemble_context() {
    local outdir="$1"
    HAS_FAILURES=0
    for name in "${ALL_CHECKS[@]}"; do
        local rc_file="$outdir/$name.rc"
        [[ -f "$rc_file" ]] || continue
        local rc
        rc=$(cat "$rc_file")
        local out="$outdir/$name.out"
        local content=""
        [[ -s "$out" ]] && content=$(cat "$out")
        if ! is_clean_check_output "$content" && ! is_info_check_output "$content"; then
            HAS_FAILURES=1
        fi
        print_check_output "$name" "$content"
    done
}

# ── Run all checks in parallel (with concurrency limit) ─────────────────────
run_all_parallel() {
    local outdir="$1"
    local max_jobs="${MAX_PARALLEL_CHECKS:-3}"
    local pids=()
    for check in "${ALL_CHECKS[@]}"; do
        # Wait for a slot if at the concurrency limit
        while [[ ${#pids[@]} -ge $max_jobs ]]; do
            # Rebuild pids array, removing finished processes
            local alive=()
            for p in "${pids[@]}"; do
                kill -0 "$p" 2>/dev/null && alive+=("$p")
            done
            pids=("${alive[@]}")
            [[ ${#pids[@]} -ge $max_jobs ]] && sleep 0.5
        done
        progress "running $check..."
        run_check_captured "$check" "$outdir" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    if "$IS_TTY"; then printf "\r\033[K" >&2; fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local audit=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --audit) audit=1; shift ;;
            *) printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2; return 1 ;;
        esac
    done

    # Interactive mode: delegate to existing script
    if [[ "$audit" -eq 0 ]]; then
        exec "$SCRIPT_DIR/pre-merge-checks.sh"
    fi

    # Audit mode (voluntary run): checks in parallel
    # Bail early if not in a git repo — nothing to diff
    if ! is_git_repo; then
        printf "\n${YELLOW}Not a git repository — skipping constitution checks.${RESET}\n" >&2
        return 0
    fi

    OUTDIR=$(mktemp -d)
    trap 'rm -rf "$OUTDIR" 2>/dev/null' EXIT

    printf "\n${CYAN}${BOLD}Constitution checks${RESET}" >&2
    measure_diff
    printf " (%s files, ~%s lines changed)\n" "$DIFF_FILES" "$DIFF_LINES" >&2

    run_all_parallel "$OUTDIR"
    assemble_context "$OUTDIR"

    if [[ "$HAS_FAILURES" -eq 1 ]]; then
        printf "\n${YELLOW}${BOLD}Some checks reported issues.${RESET}\n" >&2
    else
        printf "\n${GREEN}${BOLD}All constitution checks passed.${RESET}\n" >&2
    fi
}

main "$@"
