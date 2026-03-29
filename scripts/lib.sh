#!/usr/bin/env bash
# Shared helpers for pre-merge and parallel check scripts.

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

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
