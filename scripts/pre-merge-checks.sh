#!/usr/bin/env bash
# Pre-merge checks — invoke coding agent with focused prompts, detect changes, accept/discard.
# Usage:
#   scripts/pre-merge-checks.sh              # interactive selection of all checks
#   scripts/pre-merge-checks.sh dry          # run a single check by name
#   PRE_MERGE_CHECKS=yynnyn scripts/pre-merge-checks.sh  # preset selection
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# ── Agent command (configurable via env) ──────────────────────────────────────
AGENT_CMD="${AGENT_CMD:-claude}"

# ── Run agent with streaming progress ────────────────────────────────────────
# Invokes claude -p with stream-json output and displays a single updating
# progress line showing the current tool being called.  Falls back to plain
# pipe when jq is not available.
if command -v jq &>/dev/null; then
    run_agent_with_progress() {
        local prompt="$1"
        local is_tty=false
        if [[ -t 2 ]]; then is_tty=true; fi

        $AGENT_CMD -p "$prompt" \
            --allowedTools Edit,Read,Write,Grep,Glob,Bash \
            --output-format stream-json 2>/dev/null \
        | while IFS= read -r line; do
            local evt_type
            evt_type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null) || continue

            case "$evt_type" in
                assistant)
                    local tool_name
                    tool_name=$(printf '%s' "$line" | jq -r '
                        [.message.content[] | select(.type == "tool_use") | .name]
                        | last // empty
                    ' 2>/dev/null) || true
                    if [[ -n "${tool_name:-}" ]]; then
                        local hint
                        hint=$(printf '%s' "$line" | jq -r '
                            [.message.content[] | select(.type == "tool_use")]
                            | last
                            | .input
                            | (.file_path // .command // .pattern // .path // empty)
                        ' 2>/dev/null | head -1 | cut -c1-60) || true
                        if "$is_tty"; then
                            if [[ -n "${hint:-}" ]]; then
                                printf "\r\033[K  ${YELLOW}⟳ %s${RESET} %s" "$tool_name" "$hint" >&2
                            else
                                printf "\r\033[K  ${YELLOW}⟳ %s${RESET}" "$tool_name" >&2
                            fi
                        else
                            if [[ -n "${hint:-}" ]]; then
                                printf "  > %s %s\n" "$tool_name" "$hint" >&2
                            else
                                printf "  > %s\n" "$tool_name" >&2
                            fi
                        fi
                    fi
                    ;;
                result)
                    if "$is_tty"; then
                        printf "\r\033[K" >&2
                    fi
                    printf '%s' "$line" | jq -r '.result // empty' 2>/dev/null | sed 's/^/  /' || true
                    ;;
            esac
        done || true
    }
else
    run_agent_with_progress() {
        local prompt="$1"
        $AGENT_CMD -p "$prompt" \
            --allowedTools Edit,Read,Write,Grep,Glob,Bash 2>&1 | sed 's/^/  /'
    }
fi

# ── Diff context: changes since branch diverged from main ─────────────────────
# On main: diff against origin/main (unpushed local changes).
# On feature branch: diff against merge-base with main (branch changes).
git_diff_context() {
    local base
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [[ "$branch" == "main" ]]; then
        base=$(git rev-parse origin/main 2>/dev/null || echo "HEAD~10")
    else
        base=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~10")
    fi
    git diff "$base"..HEAD -- ':!issues/' ':!history/' 2>/dev/null || true
}

# ── Check table ───────────────────────────────────────────────────────────────
# Each check: name|label|pre-command (empty if none)
# Prompts are built in run_check() to keep them readable.
CHECK_NAMES=(dry pure plan test specs lessons)
CHECK_LABELS=(
    "Check DRY principle"
    "Check PURE principle"
    "Check issue plan completeness"
    "Run tests, inspect results"
    "Check specs/README sync"
    "Check for lessons to capture"
)
CHECK_PRE_CMDS=("" "" "" "make test 2>&1" "" "")

# ── Prompts ───────────────────────────────────────────────────────────────────
build_prompt() {
    local name="$1"
    local pre_output="$2"
    local diff_ctx="$3"

    case "$name" in
        dry)
            cat <<PROMPT
You are a code reviewer. Review the following diff for DRY (Don't Repeat Yourself) violations.
Look for: duplicated logic, copy-pasted code blocks, functions that could be consolidated,
repeated patterns that should be extracted into shared helpers.

If you find violations, refactor the code to fix them. If the code is already DRY, say so and make no changes.

Only modify files that have actual DRY violations. Do not refactor code that is not in the diff.

Diff:
$diff_ctx
PROMPT
            ;;
        pure)
            cat <<PROMPT
You are a code reviewer. Review the following diff for PURE principle adherence.
The PURE principle means: write the majority of code as pure functions (no side effects, deterministic),
then use minimal "glue" code to integrate with UI and IO.

Look for: business logic mixed with IO, functions that could be pure but aren't,
side effects that could be moved to the boundary.

If you find violations, refactor to separate pure logic from impure integration. If already clean, say so.

Only modify files in the diff. Do not touch unrelated code.

Diff:
$diff_ctx
PROMPT
            ;;
        plan)
            cat <<PROMPT
You are a project management reviewer. Check all issue files in issues/*.md for completeness:

1. Does each open issue have a filled-in Plan section with checklist items?
2. Are all plan checklist items marked complete (checked off)?
3. Does the Log section have entries documenting what was done?
4. Is the status frontmatter set correctly (done if all work is complete)?

Fix any issues you find — check off completed items, update status, add missing log entries
based on git history. If everything is in order, say so.
Only modify files in the diff. Do not touch unrelated code.
PROMPT
            ;;
        test)
            cat <<PROMPT
You are a test results analyst. The following is the output from running the test suite.
Analyze the results:

1. Are there any test failures? If so, identify the root cause and fix the code.
2. Are there any errors or warnings that indicate problems?
3. Are there flaky or suspicious test results?

If all tests pass cleanly, say "All tests pass" and make no changes.
If there are failures, fix them.

Test output:
$pre_output
PROMPT
            ;;
        specs)
            cat <<PROMPT
You are a documentation reviewer. Compare the code changes in the diff below against:
1. The spec files in specs/
2. README.md

Those files do not meant to be comprehensive. Synthesize what we just built into reusable spec document. DO NOT over specify — `specs/` is a practical way pointer for future developers and agents to know the sketch of functionalities, history and intention behind them. Details should live in the code

Update any stale documentation. Incorrect information is bad. If everything is in sync, say so and make no changes.

Only update documentation that is actually out of sync. Do not rewrite documentation that is fine.

Diff:
$diff_ctx
PROMPT
            ;;
        lessons)
            cat <<PROMPT
You are reviewing the recent work session for lessons learned. Check:

1. Were there any mistakes, false starts, or corrections during this session?
2. Are there patterns that should be captured to prevent future mistakes?
3. Is there anything in the git log (recent commits) that suggests a lesson?

Only add genuinely important, non-obvious lessons. Do not add trivial observations. Keep wording very concise, just enough to remind you of issues, not full details.

If there are no meaningful lessons to capture, say so and make no changes.
PROMPT
            ;;
    esac
}

# ── Run a single check ───────────────────────────────────────────────────────
run_check() {
    local idx="$1"
    local name="${CHECK_NAMES[$idx]}"
    local label="${CHECK_LABELS[$idx]}"
    local pre_cmd="${CHECK_PRE_CMDS[$idx]}"

    printf "\n${CYAN}━━━ %s: %s ━━━${RESET}\n" "$name" "$label"

    # Snapshot repo state
    local before
    before=$(git status --porcelain)

    # Run pre-command if any
    local pre_output=""
    if [[ -n "$pre_cmd" ]]; then
        printf "${BOLD}  Running: %s${RESET}\n" "$pre_cmd"
        pre_output=$(eval "$pre_cmd" 2>&1) || true
        printf "%s\n" "$pre_output" | tail -20 | sed 's/^/  /'
    fi

    # Build prompt and invoke agent
    local diff_ctx
    diff_ctx=$(git_diff_context)
    local prompt
    prompt=$(build_prompt "$name" "$pre_output" "$diff_ctx")

    printf "${BOLD}  Invoking agent...${RESET}\n"
    run_agent_with_progress "$prompt"

    # Detect changes
    local after
    after=$(git status --porcelain)

    if [[ "$before" != "$after" ]]; then
        printf "\n${YELLOW}  ⚠ Files changed:${RESET}\n"
        git diff --stat | sed 's/^/    /'
        # Also show new untracked files
        git ls-files --others --exclude-standard | sed 's/^/    + /'

        printf "${BOLD}  Accept changes? [Y/n]: ${RESET}"
        read -r answer </dev/tty
        if [[ "$answer" == "n" || "$answer" == "N" ]]; then
            printf "  ${RED}Discarding changes...${RESET}\n"
            git checkout -- . 2>/dev/null || true
            git clean -fd 2>/dev/null || true
        else
            printf "  ${GREEN}Changes accepted, committing...${RESET}\n"
            git add -A
            git commit -m "pre-merge check: $name"
        fi
    else
        printf "  ${GREEN}✓ No changes needed.${RESET}\n"
    fi

    printf "${GREEN}  ✓ %s complete${RESET}\n" "$label"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    local num_checks=${#CHECK_NAMES[@]}

    # Single-check mode: scripts/pre-merge-checks.sh <name>
    if [[ $# -ge 1 ]]; then
        local target="$1"
        for i in $(seq 0 $((num_checks - 1))); do
            if [[ "${CHECK_NAMES[$i]}" == "$target" ]]; then
                run_check "$i"
                return 0
            fi
        done
        printf "${RED}Unknown check: %s${RESET}\n" "$target"
        printf "Available: %s\n" "${CHECK_NAMES[*]}"
        return 1
    fi

    # Show menu
    printf "\n${CYAN}${BOLD}Pre-merge checks:${RESET}\n"
    for i in $(seq 0 $((num_checks - 1))); do
        printf "  ${BOLD}%d.${RESET} [%-7s] %s\n" $((i + 1)) "${CHECK_NAMES[$i]}" "${CHECK_LABELS[$i]}"
    done

    # Get selection
    local default
    default=$(printf 'y%.0s' $(seq 1 "$num_checks"))
    local selection="${PRE_MERGE_CHECKS:-}"

    if [[ -z "$selection" ]]; then
        printf "\n${BOLD}Select checks [%s] (y=run, n=skip, Enter=all): ${RESET}" "$default"
        read -r selection </dev/tty
        if [[ -z "$selection" ]]; then
            selection="$default"
        fi
    fi

    # Pad selection to full length with 'y'
    while [[ ${#selection} -lt $num_checks ]]; do
        selection="${selection}y"
    done

    # Count selected
    local count=0
    for i in $(seq 0 $((num_checks - 1))); do
        local ch="${selection:$i:1}"
        if [[ "$ch" == "y" || "$ch" == "Y" ]]; then
            count=$((count + 1))
        fi
    done

    if [[ $count -eq 0 ]]; then
        printf "\n${YELLOW}No checks selected. Skipping.${RESET}\n"
        return 0
    fi

    # Run selected checks
    local run_idx=0
    for i in $(seq 0 $((num_checks - 1))); do
        local ch="${selection:$i:1}"
        if [[ "$ch" == "y" || "$ch" == "Y" ]]; then
            run_idx=$((run_idx + 1))
            printf "\n${BOLD}Running check %d/%d${RESET}" "$run_idx" "$count"
            run_check "$i"
        fi
    done

    printf "\n${GREEN}${BOLD}All checks complete.${RESET}\n\n"
}

main "$@"
