---
id: 000192
status: working
deps: []
github_issue:
created: 2026-07-16
updated: 2026-07-16
estimate_hours: 1.2
started: 2026-07-16T17:11:59-07:00
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

## Spec

Single-base + confinement semantics (supersedes #181's ordered-roots
resolution; ARCH review at plan time):

1. **Resolution**: relative paths (tool reads *and* completion) resolve
   against the write root only. Absolute paths unchanged.
2. **Confinement**: after resolution, realpath must sit within the write root
   or one of the `tool_read_roots`-derived roots. `../ariadne/foo` passes
   (inside `~/workspace`); `../../etc/hosts` refused. Write side
   (`resolve_path_in_cwd`) already works this way — the two become symmetric.
3. **Completion**: `completion_candidates` globs `write_root .. "/" .. base .. "*"`
   only. Labels by **textual** prefix-strip of `write_root .. "/"` (glob
   preserves `..` textually — verified: `brain/../ariadne/wo*` →
   `brain/../ariadne/workshop`), so `../ariadne/…` labels come out in the
   typed form and segment-continue like cmp-path. Filter candidates through
   the new resolver so completion offers exactly what reads accept (keeps
   #181's align-completion-with-enforcement invariant).
4. **Tool context**: reword `format_tool_context` to the new contract:
   relative paths resolve from `<write_root>`; reads may traverse outside it
   but must stay within the listed roots. The chat LLM then just echoes the
   typed relative path (`ls ../ariadne` works — resolver already returns
   `/Users/…/workspace/ariadne` for it today).
5. **Deterministic attach**: re-assert parley's cmp buffer config on BufEnter
   (drop the once-only guard for the cmp part) so a host config that also
   calls `cmp.setup.buffer` on BufEnter can't silently displace it.

Known breakage (accepted, break loudly): the accidental root-relative
`ariadne/…` spelling stops resolving; resolver error names the path. #181's
ordered-precedence tests flip to the new semantics.

## Done when

- In a repo-mode chat in brain, typing `../ariadne/` offers ariadne's
  entries as `../ariadne/<name>` and segment-continues (`../ariadne/workshop/…`).
- `../../…` paths escaping all read roots neither complete nor resolve.
- `ariadne/…` (workspace-root-relative accidental form) no longer resolves;
  the error names the path.
- "tell me about ../ariadne/" in chat → agent's `ls` tool call on
  `../ariadne` succeeds via write-root resolution + confinement.
- Completion source survives buffer switches (BufEnter re-assert): still
  parley_path with write-root base after leaving/re-entering the chat buffer.
- Unit tests cover resolver (base + confinement + refusal) and completion
  (textual `..` labels, filter, single-root glob); #181 tests updated.

## Plan

Detailed plan: `workshop/plans/000192-repo-root-dot-dot-completion-plan.md`.
Single-pass close (one review boundary), plain checkboxes:

- [ ] Task 1: `resolve_read_path` → single base + confinement (wrap
  `resolve_path_in_cwd` + existence; new `(path, cwd, read_roots)` signature;
  update `execute_call` call sites; rewrite #181 unit tests)
- [ ] Task 2: `completion_candidates` → write-root glob + textual prefix-strip
  labels + resolver filter; delete `relative_to_root` +
  `merge_completion_candidates`; integration tests for `../sibling` typed-form
  completion, escape filtering, no non-base root-relative candidates
- [ ] Task 3: `format_tool_context` reword to single-base + confinement contract
- [ ] Task 4: cmp buffer config re-assert on BufEnter (drop once-only guard for
  the cmp part; flip repeat-attach test; add BufEnter re-assert test)
- [ ] Task 5: full suite + live verification in brain chat (`../ariadne/`
  completion, "tell me about ../ariadne/" ls call) + atlas
  (`infra/repo_mode.md`, `providers/tool_use.md`) + close

## Estimate

estimate_hours: 1.2 (range 0.6–1.8)

Method A: "Lua / Neovim feature (single, focused)" design 1–3 ×0.2
spec-quality (thorough plan resolves decisions) = 0.2–0.6; + atlas/docs
0.05–0.2 design; +15% buffer (plan doc) → design 0.29–0.92. Impl at 40%
(v3.1): (0.5–1.5)×0.4 + docs (0.05–0.2)×0.4 + close-review chunk
(0.2–0.5)×0.4 → 0.3–0.88. Total 0.6–1.8, midpoint 1.2.

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-16

Created from design discussion in brain repo-mode chat
(brain: workshop/parley/2026-07-16.16-38-57.920.md context). Empirically
verified in-session: glob preserves `..` textually; current
`resolve_read_path("../ariadne/pkg", {brain, workspace})` already resolves via
the brain-base candidate and confines correctly (`../../etc/hosts` refused);
`vim.fn.resolve` collapses `..`, which is what kills `..` labels today;
operator runs nvim-cmp (not blink) with a BufEnter cmp-path re-install for
markdown — source of the nondeterministic completion.
