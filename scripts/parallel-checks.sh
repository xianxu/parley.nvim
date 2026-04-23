#!/usr/bin/env bash
# Parallel constitution check runner.
# In audit mode, checks run in parallel with a concurrency limit (read-only agents).
# Set MAX_PARALLEL_CHECKS to control concurrency (default: 3).
# specs is the only check that may write files (documentation updates).
#
# Usage:
#   scripts/parallel-checks.sh                  # interactive (delegates to pre-merge-checks.sh)
#   scripts/parallel-checks.sh --audit          # all parallel, read-only, report context
#   scripts/parallel-checks.sh --hook-gate      # threshold check + nag/force mode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Shared helpers ────────────────────────────────────────────────────────────
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ALL_CHECKS=(dry pure specs plan lessons)

# ── Threshold configuration ──────────────────────────────────────────────────
THRESHOLD_LINES=300
THRESHOLD_FILES=5
GROWTH_GATE_PCT=50
FORCE_MULTIPLIER=3   # When diff >= 3x nag threshold, force-run (can't be postponed)
STATE_FILE=".constitution-check-state"
LOCK_DIR="${TMPDIR:-/tmp}/claude/parallel-checks-$(pwd | (md5sum 2>/dev/null || shasum) | cut -c1-8).lock"

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
    base=$(git_diff_base)
    DIFF_LINES=$(git diff "$base" --numstat -- ":!${WF_ISSUES_DIR:-issues}/" ":!${WF_HISTORY_DIR:-history}/" 2>/dev/null \
        | awk '{s+=$1+$2} END {print s+0}')
    DIFF_FILES=$(git diff "$base" --name-only -- ":!${WF_ISSUES_DIR:-issues}/" ":!${WF_HISTORY_DIR:-history}/" 2>/dev/null | wc -l | tr -d ' ')
}

# Read last check state into LAST_LINES and LAST_FILES.
# Resets to 0/0 if the merge base SHA has changed (new commits landed on main).
read_state() {
    LAST_LINES=0
    LAST_FILES=0
    if [[ -f "$STATE_FILE" ]]; then
        local stored_sha
        stored_sha=$(sed -n '1p' "$STATE_FILE" | tr -d ' \n')
        local current_sha
        current_sha=$(git_diff_base)
        if [[ "$stored_sha" == "$current_sha" ]]; then
            LAST_LINES=$(sed -n '2p' "$STATE_FILE" | tr -d ' \n')
            LAST_FILES=$(sed -n '3p' "$STATE_FILE" | tr -d ' \n')
            LAST_LINES=${LAST_LINES:-0}
            LAST_FILES=${LAST_FILES:-0}
        fi
        # If SHA differs, keep defaults (0/0) — merge base advanced, fresh start
    fi
}

# Compute thresholds and set HOOK_ACTION (none/nag/force)
check_action() {
    measure_diff
    read_state

    # Compute nag thresholds from last check state (or absolute defaults)
    local nag_lines nag_files growth
    if [[ "$LAST_LINES" -gt 0 ]]; then
        growth=$(( LAST_LINES * GROWTH_GATE_PCT / 100 ))
        [[ "$growth" -lt 1 ]] && growth=1
        nag_lines=$(( LAST_LINES + growth ))
    else
        nag_lines=$THRESHOLD_LINES
    fi
    if [[ "$LAST_FILES" -gt 0 ]]; then
        growth=$(( LAST_FILES * GROWTH_GATE_PCT / 100 ))
        [[ "$growth" -lt 1 ]] && growth=1
        nag_files=$(( LAST_FILES + growth ))
    else
        nag_files=$THRESHOLD_FILES
    fi

    # Force threshold: FORCE_MULTIPLIER × nag threshold
    local force_lines=$(( nag_lines * FORCE_MULTIPLIER ))
    local force_files=$(( nag_files * FORCE_MULTIPLIER ))

    # Determine action
    if [[ "$DIFF_LINES" -lt "$nag_lines" && "$DIFF_FILES" -lt "$nag_files" ]]; then
        HOOK_ACTION=none
    elif [[ "$DIFF_LINES" -ge "$force_lines" || "$DIFF_FILES" -ge "$force_files" ]]; then
        HOOK_ACTION=force
    else
        HOOK_ACTION=nag
    fi
}

update_state() {
    measure_diff
    local current_sha
    current_sha=$(git_diff_base)
    printf '%s\n%d\n%d\n' "$current_sha" "$DIFF_LINES" "$DIFF_FILES" > "$STATE_FILE"
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
    local hook_gate=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --audit) audit=1; shift ;;
            --hook-gate) hook_gate=1; shift ;;
            *) printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2; return 1 ;;
        esac
    done

    # Hook gate mode: drain stdin (Claude sends JSON), check lock, then decide action
    if [[ "$hook_gate" -eq 1 ]]; then
        cat >/dev/null 2>&1 || true  # consume stdin from Claude hook
        # Ensure parent of LOCK_DIR exists (preserves race semantics of mkdir for the lock itself)
        mkdir -p "$(dirname "$LOCK_DIR")" 2>/dev/null
        if ! mkdir "$LOCK_DIR" 2>/dev/null; then
            return 0  # another run in progress, skip silently
        fi
        trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT
        export CHECK_MODE=hook

        # Bail early if not in a git repo
        if ! is_git_repo; then
            return 0
        fi

        check_action

        case "$HOOK_ACTION" in
            none)
                return 0
                ;;
            nag)
                jq -n --arg f "$DIFF_FILES" --arg l "$DIFF_LINES" \
                    '{"additionalContext": "Constitution reminder: You have made substantial changes (\($f) files, ~\($l) lines). Consider running scripts/parallel-checks.sh --audit when you reach a good stopping point."}'
                return 0
                ;;
            force)
                # Force: run all checks and require the agent to address violations
                OUTDIR=$(mktemp -d)
                trap 'rm -rf "$OUTDIR" "$LOCK_DIR" 2>/dev/null' EXIT

                printf "Constitution check (forced): Change is very large (%s files, ~%s lines). Running checks now.\n" \
                    "$DIFF_FILES" "$DIFF_LINES" >&2

                run_all_parallel "$OUTDIR"
                assemble_context "$OUTDIR"
                update_state

                if [[ "$HAS_FAILURES" -eq 1 ]]; then
                    local check_output msg
                    check_output=$(cat "$OUTDIR"/*.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
                    msg="Constitution check (forced): Very large change ($DIFF_FILES files, ~$DIFF_LINES lines). Violations found — STOP what you are doing and address these NOW before any further edits."$'\n\n'"$check_output"$'\n\nYou MUST fix the above violations immediately. Do not proceed with any other task until these are resolved.'
                    jq -n --arg m "$msg" '{"additionalContext": $m}'
                else
                    jq -n --arg m "Constitution check (forced): Very large change ($DIFF_FILES files, ~$DIFF_LINES lines). All checks passed." '{"additionalContext": $m}'
                fi
                return 0
                ;;
        esac
    fi

    # Interactive mode: delegate to existing script
    if [[ "$audit" -eq 0 ]]; then
        exec "$SCRIPT_DIR/pre-merge-checks.sh"
    fi

    # Audit mode (voluntary run): checks in parallel, then update state
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

    # Always update state after a voluntary audit — resets nag threshold
    update_state

    if [[ "$HAS_FAILURES" -eq 1 ]]; then
        printf "\n${YELLOW}${BOLD}Some checks reported issues.${RESET}\n" >&2
    else
        printf "\n${GREEN}${BOLD}All constitution checks passed.${RESET}\n" >&2
    fi
}

main "$@"
