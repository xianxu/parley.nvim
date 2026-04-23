#!/usr/bin/env bash
# Shared helpers for pre-merge and parallel check scripts.

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# ── Output helpers ──────────────────────────────────────────────────────────
# Detect whether check output indicates a clean result (no violations).
# Returns 0 if clean, 1 if violations found.
# Empty output is NOT clean — it likely means the agent failed silently.
is_clean_check_output() {
    local output="$1"
    [[ -z "$output" ]] && return 1
    # Known clean patterns from agent prompts
    echo "$output" | grep -qiE \
        'no (DRY|PURE) violations found|all tests pass|no changes needed|in sync|no issue files changed' \
        && return 0
    return 1
}

# Informational output — shown but not treated as a failure.
is_info_check_output() {
    local output="$1"
    echo "$output" | grep -qiE 'REMINDER:' && return 0
    return 1
}

# Emit a check message — formats with pass/fail in interactive mode, raw text in audit mode.
# Usage: emit_check_message <label> <output>
emit_check_message() {
    local label="$1" msg="$2"
    if [[ "${CHECK_NO_COMMIT:-}" == "1" ]]; then
        printf '%s\n' "$msg"
    else
        print_check_output "$label" "$msg"
    fi
}

# Print check result with consistent pass/fail formatting.
# Usage: print_check_output <label> <output>
print_check_output() {
    local label="$1"
    local output="$2"
    if is_clean_check_output "$output"; then
        printf "  ${GREEN}✓ %s${RESET}\n" "$label" >&2
    elif is_info_check_output "$output"; then
        printf "  ${YELLOW}ℹ %s${RESET}\n" "$label" >&2
        printf "  %s\n" "$output" >&2
    else
        printf "  ${RED}✗ %s${RESET}\n" "$label" >&2
        printf "${RED}%s${RESET}\n" "$output" >&2
    fi
}

# ── Git helpers ───────────────────────────────────────────────────────────────
# Check if we're inside a git repository.
is_git_repo() { git rev-parse --git-dir &>/dev/null; }

# Resolve the git ref to diff against.
# Priority: COMPARE-SHA file > on main: origin/main > on branch: merge-base with main.
git_diff_base() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" && -f "$root/COMPARE-SHA" ]]; then
        local sha
        sha=$(head -1 "$root/COMPARE-SHA" | tr -d '[:space:]')
        if [[ -n "$sha" ]] && git rev-parse --verify "$sha" &>/dev/null; then
            echo "$sha"
            return
        fi
    fi
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [[ "$branch" == "main" ]]; then
        git rev-parse origin/main 2>/dev/null || echo "HEAD~10"
    else
        git merge-base main HEAD 2>/dev/null || echo "HEAD~10"
    fi
}
