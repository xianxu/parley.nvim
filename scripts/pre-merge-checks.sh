#!/usr/bin/env bash
# Pre-merge checks — invoke coding agent with focused prompts, detect changes, accept/discard.
# Usage:
#   scripts/pre-merge-checks.sh              # interactive selection of all checks
#   scripts/pre-merge-checks.sh dry          # run a single check by name
#   PRE_MERGE_CHECKS=yynnyn scripts/pre-merge-checks.sh  # preset selection
set -euo pipefail

# ── Shared helpers ────────────────────────────────────────────────────────────
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ── Agent command (configurable via env) ──────────────────────────────────────
AGENT_CMD="${AGENT_CMD:-claude}"
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Edit,Read,Write,Grep,Glob,Bash}"

# Sandbox detection: inside Docker container = full auto-approve
is_sandbox() { [[ -f /.dockerenv ]]; }

# ── Agent adapters ───────────────────────────────────────────────────────────
# Each adapter builds the correct command line for its agent.
# Returns the command via stdout (eval-safe).

agent_run_claude() {
    local prompt="$1" stream="$2"
    local cmd="claude -p"
    cmd+=" --allowedTools $(printf '%q' "$ALLOWED_TOOLS")"
    cmd+=" --permission-mode bypassPermissions"
    if [[ "$stream" == "1" ]]; then
        cmd+=" --verbose --output-format stream-json"
    fi
    cmd+=" $(printf '%q' "$prompt")"
    echo "$cmd"
}

agent_run_codex() {
    local prompt="$1" stream="$2"
    local cmd="codex exec"
    if is_sandbox; then
        cmd+=" --full-auto"
    fi
    cmd+=" $(printf '%q' "$prompt")"
    echo "$cmd"
}

agent_run_gemini() {
    local prompt="$1" stream="$2"
    local cmd="gemini"
    if is_sandbox; then
        cmd+=" --yolo"
    fi
    cmd+=" -p $(printf '%q' "$prompt")"
    echo "$cmd"
}

# Resolve the adapter function name for the current AGENT_CMD
agent_adapter() {
    case "$AGENT_CMD" in
        claude) echo "agent_run_claude" ;;
        codex)  echo "agent_run_codex" ;;
        gemini) echo "agent_run_gemini" ;;
        *)
            printf "${RED}Unknown AGENT_CMD: %s (supported: claude, codex, gemini)${RESET}\n" "$AGENT_CMD" >&2
            return 1
            ;;
    esac
}

# ── Run agent with streaming progress ────────────────────────────────────────
# For claude: parses stream-json output and displays tool-call progress.
# For other agents: pipes output directly (no structured streaming).
if command -v jq &>/dev/null; then
    run_agent_with_progress() {
        local prompt="$1"
        local adapter
        adapter=$(agent_adapter) || return 1
        local is_tty=false
        if [[ -t 2 ]]; then is_tty=true; fi

        # Only claude supports stream-json progress
        if [[ "$AGENT_CMD" == "claude" ]]; then
            local cmd
            cmd=$($adapter "$prompt" 1)
            eval "$cmd" 2>/dev/null \
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
        else
            local cmd
            cmd=$($adapter "$prompt" 0)
            eval "$cmd" 2>&1 | sed 's/^/  /'
        fi
    }
else
    run_agent_with_progress() {
        local prompt="$1"
        local adapter
        adapter=$(agent_adapter) || return 1
        local cmd
        cmd=$($adapter "$prompt" 0)
        eval "$cmd" 2>&1 | sed 's/^/  /'
    }
fi

# ── Diff context: changes since branch diverged from main ─────────────────────
_git_diff_base() {
    local base
    base=$(git_diff_base)
    # No "..HEAD" — include uncommitted working-tree changes so pre-merge
    # checks can review work-in-progress, not just committed history.
    git diff "$base" "$@" 2>/dev/null || true
}

git_diff_context()        { _git_diff_base -- ":!${WF_ISSUES_DIR:-issues}/" ":!${WF_HISTORY_DIR:-history}/"; }
git_diff_context_issues() { _git_diff_base -- "${WF_ISSUES_DIR:-issues}/*.md"; }
git_changed_issues()      { _git_diff_base --name-only -- "${WF_ISSUES_DIR:-issues}/*.md"; }

# ── Check table ───────────────────────────────────────────────────────────────
# Each check: name|label|pre-command (empty if none)
# Prompts are built in run_check() to keep them readable.
CHECK_NAMES=(dry pure plan specs lessons)
CHECK_LABELS=(
    "Check DRY principle"
    "Check PURE principle"
    "Check issue plan completeness"
    "Check atlas/README sync"
    "Check for lessons to capture"
)
CHECK_PRE_CMDS=("" "" "" "" "")

# ── Prompts ───────────────────────────────────────────────────────────────────
build_prompt() {
    local name="$1"
    local pre_output="$2"
    local diff_ctx="$3"
    local changed_issues="${4:-}"

    case "$name" in
        dry)
            cat <<PROMPT
You are a code reviewer. Review the following diff for DRY (Don't Repeat Yourself) violations.
Look for: duplicated logic, copy-pasted code blocks, functions that could be consolidated,
repeated patterns that should be extracted into shared helpers.

Report any violations you find with file paths and line numbers. Suggest how to fix them.
Do NOT modify any files. Only report.

If the code is already DRY, say "No DRY violations found."

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

Report any violations with file paths and line numbers. Suggest how to refactor.
Do NOT modify any files. Only report.

If the code is clean, say "No PURE violations found."

Diff:
$diff_ctx
PROMPT
            ;;
        plan)
            cat <<PROMPT
You are a project management reviewer (TPM). You don't know technical details.
Only review the issue files that changed in this diff — do NOT review other issues.

For each changed issue file, check:
1. Does it have a filled-in Plan section with checklist items?
2. Are plan checklist items that appear done (based on the diff and git log) still unchecked?
3. Does the Log section have entries documenting what was done?
4. Is the status frontmatter correct (should it be "done")?

Report any issues you find. Do NOT modify any files.
If a checklist item looks completed based on the diff, say so and recommend checking it off.

Changed issue files:
$changed_issues

Diff:
$diff_ctx
PROMPT
            ;;
        specs)
            cat <<PROMPT
You are a documentation reviewer. Compare the code changes in the diff below against:
1. The spec files in atlas/
2. README.md

Those files do not meant to be comprehensive. Synthesize what we just built into reusable spec document. DO NOT over specify — atlas/ is a practical pointer for future developers and agents to know the sketch of functionalities, history and intention behind them. Details should live in the code.

Update any stale documentation. Incorrect information is bad. If everything is in sync, say so and make no changes.

Only update documentation that is actually out of sync. Do not rewrite documentation that is fine.

Diff:
$diff_ctx
PROMPT
            ;;
        lessons)
            # No agent — handled directly in run_check
            return 0
            ;;
    esac
}

# ── Run a single check ───────────────────────────────────────────────────────
run_check() {
    local idx="$1"
    local name="${CHECK_NAMES[$idx]}"
    local label="${CHECK_LABELS[$idx]}"
    local pre_cmd="${CHECK_PRE_CMDS[$idx]}"

    printf "\n${CYAN}━━━ %s: %s ━━━${RESET}\n" "$name" "$label" >&2

    # Snapshot repo state
    local before
    before=$(git status --porcelain)

    # Run pre-command if any
    local pre_output=""
    if [[ -n "$pre_cmd" ]]; then
        printf "${BOLD}  Running: %s${RESET}\n" "$pre_cmd" >&2
        pre_output=$(eval "$pre_cmd" 2>&1) || true
        printf "%s\n" "$pre_output" | tail -20 | sed 's/^/  /' >&2
    fi

    # Handle checks that don't need an agent
    local changed_issues=""
    case "$name" in
        plan)
            changed_issues=$(git_changed_issues)
            if [[ -z "$changed_issues" ]]; then
                emit_check_message "$label" "No issue files changed — skipping plan check."
                return 0
            fi
            ;;
        lessons)
            emit_check_message "$label" "REMINDER: Review workshop/lessons.md — capture any non-obvious patterns from this session."
            return 0
            ;;
    esac

    # Build prompt and invoke agent
    local diff_ctx
    if [[ "$name" == "plan" ]]; then
        diff_ctx=$(git_diff_context_issues)
    else
        diff_ctx=$(git_diff_context)
    fi
    local prompt
    prompt=$(build_prompt "$name" "$pre_output" "$diff_ctx" "$changed_issues")

    printf "${BOLD}  Invoking agent...${RESET}\n" >&2
    local agent_output
    agent_output=$(run_agent_with_progress "$prompt")
    emit_check_message "$label" "$agent_output"

    # In no-commit mode (parallel/audit), skip change detection — caller handles formatting
    if [[ "${CHECK_NO_COMMIT:-}" == "1" ]]; then
        return 0
    fi

    # Detect changes
    local after
    after=$(git status --porcelain)

    if [[ "$before" != "$after" ]]; then
        printf "\n${YELLOW}  ⚠ Files changed:${RESET}\n" >&2
        git diff --stat | sed 's/^/    /' >&2
        # Also show new untracked files
        git ls-files --others --exclude-standard | sed 's/^/    + /' >&2

        printf "${BOLD}  Accept changes? [Y/n]: ${RESET}" >&2
        read -r answer </dev/tty
        if [[ "$answer" == "n" || "$answer" == "N" ]]; then
            printf "  ${RED}Discarding changes...${RESET}\n" >&2
            git checkout -- . 2>/dev/null || true
            git clean -fd 2>/dev/null || true
        else
            printf "  ${GREEN}Changes accepted, committing...${RESET}\n" >&2
            git add -A
            git commit -m "pre-merge check: $name"
        fi
    else
        printf "  ${GREEN}✓ No changes needed.${RESET}\n" >&2
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    if ! is_git_repo; then
        printf "\n${YELLOW}Not a git repository — skipping pre-merge checks.${RESET}\n" >&2
        return 0
    fi

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
    if [[ "$selection" == "none" ]]; then
        selection=$(printf 'n%.0s' $(seq 1 "$num_checks"))
    fi

    if [[ -z "$selection" ]]; then
        printf "\n${BOLD}Select checks [%s] (y=run, n=skip, Enter=all, 'none' to skip all): ${RESET}" "$default"
        read -r selection </dev/tty
        if [[ -z "$selection" ]]; then
            selection="$default"
        elif [[ "$selection" == "none" ]]; then
            selection=$(printf 'n%.0s' $(seq 1 "$num_checks"))
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
