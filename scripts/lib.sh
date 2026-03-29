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
is_clean_check_output() {
    local output="$1"
    # Empty output counts as clean
    [[ -z "$output" ]] && return 0
    # Known clean patterns from agent prompts
    echo "$output" | grep -qiE \
        'no (DRY|PURE) violations found|all tests pass|no changes needed|in sync|no issue files changed|REMINDER:' \
        && return 0
    return 1
}

# Print text, wrapping in red if it contains violations.
print_check_output() {
    local output="$1"
    if is_clean_check_output "$output"; then
        printf '%s\n' "$output"
    else
        printf "${RED}%s${RESET}\n" "$output"
    fi
}

# ── Git diff base ────────────────────────────────────────────────────────────
# On main: diff against origin/main (unpushed local changes).
# On feature branch: diff against merge-base with main (branch changes).
git_diff_base() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [[ "$branch" == "main" ]]; then
        git rev-parse origin/main 2>/dev/null || echo "HEAD~10"
    else
        git merge-base main HEAD 2>/dev/null || echo "HEAD~10"
    fi
}
