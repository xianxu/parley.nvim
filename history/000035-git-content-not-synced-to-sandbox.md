---
id: 000035
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# git content not synced to sandbox

we need it for some repo command to work, for example, to figure out what changed.

## Done when

- `git diff`, `git log`, `git branch` work on the sandbox
- pre-merge checks (`make check-dry` etc.) can compute diff context

## Plan

- [x] Diagnose: mutagen `--ignore-vcs` skips `.git/` — no git history on sandbox
- [x] Add one-way-replica sync of `.git/` from host to sandbox
- [x] Add cleanup of git sync on `sandbox stop`
- [x] Manual verification: rebuild sandbox, confirm `git log` works

## Log

### 2026-03-29

- Root cause: all three mutagen syncs use `--ignore-vcs` which excludes `.git/`. Scripts like `git_diff_base()`, `git diff`, `git branch` all fail without it.
- Fix: added a separate `one-way-replica` mutagen sync for `$REPO_DIR/.git` → `/sandbox/repo/.git`. One-way prevents index/lock file conflicts. Ignores `index.lock` to avoid transient lock issues.
- Needs manual verification: `make sandbox-stop && make sandbox`, then run `git log` and `make check-dry` on sandbox.
