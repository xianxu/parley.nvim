# Issue Sync

Syncs `workshop/issues/` changes to main and pushes to origin, even from a feature branch. This enables using issue files as a coordination/locking mechanism across branches and collaborators.

## Usage

```
make issue-sync
```

## Behavior

### On main

Stages all changes and untracked files in `workshop/issues/`, commits, and pushes to origin.

### On a feature branch (worktree)

1. Identifies changed + untracked files in `workshop/issues/` on the feature branch
2. Finds the main worktree and verifies it's on `main`
3. Pulls latest main from origin (`git pull --rebase`)
4. Computes the merge base and checks for conflicts (files changed on both sides)
5. **No conflicts**: copies files to main worktree, commits, pushes
6. **Conflicts detected**: stops and prints step-by-step resolution instructions

## Conflict detection

A conflict is when the same issue file was modified on both:
- The feature branch (since it diverged from main)
- Main itself (since the merge base)

When this happens, the script stops and tells the user exactly which files conflict and how to resolve them manually in the main worktree.

## Why

Issue state changes (status, assignment) need to be visible on main immediately, not deferred until a feature branch merges. This avoids two people picking up the same issue, and keeps the `workshop/issues/` folder on main as the single source of truth for coordination.

## Implementation

- Script: `scripts/issue-sync.sh`
- Makefile target: `issue-sync` (in `Makefile.workflow`)
