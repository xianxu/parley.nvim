---
id: '000192'
status: done
started: 2026-07-16T17:11:59-07:00
created: 2026-07-16
updated: 2026-07-16
estimate_hours: 1.2
actual_hours: 0.95
---

# repo-root relative paths with dot-dot completion

## Problem

In repo mode, a chat's relative-path semantics conflate two concepts that
should be separate:

- **Resolution base** — what a relative path *means*. Should be exactly one:
  the neighborhood write root (repo root in repo mode), like a process cwd.
- **Permission boundary** — where a resolved path may *land*. That's
  `tool_read_roots` (default `{'../'}`): a confinement allowlist, like a
  sandbox.

Today `resolve_read_path` treats every read root as an *ordered resolution
base* ("first existing match wins", #181), and `neighborhood.completion_candidates`
globs per-root with normalize-then-prefix-strip labeling. Consequences:

1. `../ariadne/…` never completes: glob finds the matches, but
   `relative_to_root` normalizes the `..` away (`vim.fn.resolve` collapses it),
   the result no longer prefixes the write root, and the candidate is dropped.
2. Peer-repo files accidentally complete/resolve as `ariadne/…` — an artifact
   of the permission entry `'../'` doubling as a base. Operator intent:
   `tool_read_roots` was *only* ever meant as read permission.
3. Chat-buffer completion is nondeterministic: parley attaches its cmp
   buffer config once (guarded + `once=true` InsertEnter), while the
   operator's nvim config re-installs cmp-path on **every** BufEnter for
   markdown. After a buffer switch, cmp-path silently wins with a different
   base dir (the chat file's dir, not repo root).
