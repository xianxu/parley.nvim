#!/usr/bin/env bash
# Sync workshop/issues/ changes to main and push to origin.
# Works from main (direct commit+push) or from a feature branch/worktree
# (detects conflicts, copies safe changes to main, commits, pushes).
set -euo pipefail

source "$(dirname "$0")/lib.sh"

ISSUES_DIR="${WF_ISSUES_DIR:-issues}"

# ── Helpers ──────────────────────────────────────────────────────────────────

die()  { printf "${RED}Error: %s${RESET}\n" "$1" >&2; exit 1; }
info() { printf "${CYAN}==> %s${RESET}\n" "$1" >&2; }
ok()   { printf "${GREEN}  [ok] %s${RESET}\n" "$1" >&2; }
warn() { printf "${YELLOW}  [!] %s${RESET}\n" "$1" >&2; }

# List files changed or untracked in $ISSUES_DIR on the current branch.
# Outputs paths relative to repo root.
changed_issue_files() {
    {
        # Modified (staged + unstaged) relative to HEAD
        git diff --name-only HEAD -- "$ISSUES_DIR/" 2>/dev/null || true
        # Staged but not yet committed
        git diff --cached --name-only -- "$ISSUES_DIR/" 2>/dev/null || true
        # Untracked
        git ls-files --others --exclude-standard -- "$ISSUES_DIR/" 2>/dev/null || true
    } | sort -u
}

# ── Case 1: On main ─────────────────────────────────────────────────────────

sync_on_main() {
    local changed
    changed=$(changed_issue_files)

    if [ -z "$changed" ]; then
        ok "No issue changes to sync."
        exit 0
    fi

    info "Syncing issue changes on main..."
    echo "$changed" | sed 's/^/  /'

    git add $ISSUES_DIR/
    git commit -m "issue-sync: update issues" || die "commit failed"
    git push origin main || die "push failed"
    ok "Issues synced and pushed to origin/main."
}

# ── Case 2: On feature branch ───────────────────────────────────────────────

sync_on_branch() {
    local branch
    branch=$(git branch --show-current)

    # 1. Identify changed issue files on the feature branch
    local changed
    changed=$(changed_issue_files)

    if [ -z "$changed" ]; then
        ok "No issue changes to sync."
        exit 0
    fi

    info "Issue files changed on branch '$branch':"
    echo "$changed" | sed 's/^/  /'

    # 2. Find the main worktree
    local main_path
    main_path=$(git worktree list --porcelain | awk '/^worktree /{path=$2} /branch refs\/heads\/main$/{print path}')

    if [ -z "$main_path" ]; then
        die "Could not find a worktree on branch 'main'. Is main checked out somewhere?"
    fi

    # Verify main worktree is actually on main
    local main_branch
    main_branch=$(git -C "$main_path" branch --show-current)
    if [ "$main_branch" != "main" ]; then
        die "Expected main worktree to be on 'main', but it's on '$main_branch'."
    fi

    # Check main worktree has no uncommitted issue changes
    local main_dirty
    main_dirty=$(git -C "$main_path" diff --name-only -- "$ISSUES_DIR/" 2>/dev/null || true)
    main_dirty+=$(git -C "$main_path" diff --cached --name-only -- "$ISSUES_DIR/" 2>/dev/null || true)
    if [ -n "$main_dirty" ]; then
        die "Main worktree has uncommitted issue changes. Commit or stash them first:\n$main_dirty"
    fi

    ok "Main worktree found at: $main_path"

    # 3. Pull latest main from origin
    info "Pulling latest main from origin..."
    git -C "$main_path" pull --rebase origin main || die "Failed to pull main from origin."

    # 4. Check for conflicts: files changed on both main (since merge base) and feature branch
    local merge_base
    merge_base=$(git merge-base main HEAD 2>/dev/null) || die "Cannot find merge base between main and HEAD."

    local main_changed
    main_changed=$(git diff --name-only "$merge_base" main -- "$ISSUES_DIR/" 2>/dev/null || true)

    local conflicts=""
    for f in $changed; do
        if echo "$main_changed" | grep -qxF "$f"; then
            conflicts="$conflicts\n  $f"
        fi
    done

    # 5. If conflicts, stop and guide the user
    if [ -n "$conflicts" ]; then
        printf "${RED}Conflict detected!${RESET}\n" >&2
        printf "These issue files were changed on both your branch and main:\n" >&2
        printf "$conflicts\n\n" >&2
        printf "To resolve:\n" >&2
        printf "  1. cd %s\n" "$main_path" >&2
        printf "  2. For each file above, open it and manually merge your changes.\n" >&2
        printf "     Your branch versions are at: %s\n" "$(git rev-parse --show-toplevel)" >&2
        printf "  3. git add %s/\n" "$ISSUES_DIR" >&2
        printf "  4. git commit -m \"issue-sync: resolve conflicts\"\n" >&2
        printf "  5. git push origin main\n" >&2
        exit 1
    fi

    ok "No conflicts detected."

    # 6. Copy changed files to main worktree
    info "Copying issue files to main worktree..."
    local wt_root
    wt_root=$(git rev-parse --show-toplevel)

    for f in $changed; do
        local dest="$main_path/$f"
        mkdir -p "$(dirname "$dest")"
        cp "$wt_root/$f" "$dest"
        echo "  $f"
    done

    # 7. Commit and push on main
    info "Committing and pushing on main..."
    git -C "$main_path" add "$ISSUES_DIR/"
    git -C "$main_path" commit -m "issue-sync: update issues from branch '$branch'" || die "commit failed"
    git -C "$main_path" push origin main || die "push failed"

    ok "Issues synced to main and pushed to origin."
}

# ── Main ─────────────────────────────────────────────────────────────────────

current_branch=$(git branch --show-current)

if [ "$current_branch" = "main" ]; then
    sync_on_main
else
    sync_on_branch
fi
