---
id: 000208
status: working
deps: [ariadne#225]
github_issue:
created: 2026-09-02
updated: 2026-09-13
estimate_hours: 2.494
started: 2026-09-13T12:19:41-07:00
---

# parley must install and load from a fresh clone

## Problem

`require("parley")` raises on any machine without the ariadne sibling repo.
Reproduced by extracting `git archive HEAD` into a fresh directory:

```
issue_vocabulary.lua:147: failed to read issue vocabulary:
  <cwd>/construct/generated/vocabulary/issue.json
```

`init.lua:110-111` calls `issues_mod.setup(M)` at module top level, which reaches
`issue_vocabulary.default()` -> `load()` -> `error()`. The JSON is gitignored
(`.gitignore:43`) and produced by a cue export from `../ariadne`. A `lazy.nvim`
install hits the same path, so the plugin is currently installable only by its
author.

The dependency surface splits into three layers, and only the first reaches users:

1. **Runtime data** — one 4,776-byte file. `construct/generated/vocabulary/issue.json`
   is the only thing `lua/` reads out of `construct/`.
2. **Runtime binary** — `sdlc`. Already `executable()`-guarded for `gf`/`gP`
   (`artifact_ref.lua:116`); only `issues.lua:382` shells out unguarded.
3. **Dev-time symlinks** — 28 tracked symlinks into `../ariadne`, including
   `Makefile` itself, so a contributor cannot run `make test` on a bare clone.
   One (`scripts/issue-sync.sh`) already dangles on the author's machine.

## Spec

Separate the shipped user product from ariadne development infrastructure, so a
fresh clone loads and a fresh contributor can run the tests.

- Vendor the generated vocabulary into the repo at its existing path, so
  `nvim_get_runtime_file()` resolves it and no code change is needed on the happy
  path. Verified sufficient: with only that file restored, `require` and
  `setup({})` both succeed on a clean `git archive` extract.
- Keep derivation enforced rather than documented (`ARCH-PURPOSE`). The `.cue`
  file remains the single source; `.source-sha` already sits beside the JSON. Add
  a check that regenerates and diffs against the committed copy, run where
  ariadne is present. A vendored build artifact under an enforced drift check is
  not a second source of truth (`ARCH-DRY`).
- Make `issue_vocabulary.default()` non-fatal so a missing or corrupt file
  degrades the issue features instead of failing plugin load (Root Cause: load
  must not depend on an optional subsystem's data).
- Guard `issues.lua:382` with the same `executable()` check `artifact_ref.lua`
  already uses.
- Make `Makefile` a real file that includes the already-real, self-contained
  `Makefile.parley` and `-include`s the ariadne overlay when present, so
  `make test` works on a bare clone without removing the maintainer workflow.
- Untrack maintainer-only infrastructure that dangles for everyone else:
  `.openshell/`, `.tart/`, `.codex/`, `.claude/settings.ariadne.json`,
  `construct/scripts/*`, `atlas/workflow`, and the ariadne-only `scripts/*`.
  Keep them locally via gitignore.
- No new runtime dependency is introduced (`ARCH-MOCK`: N/A — this removes a
  dependency rather than adding one).

## Done when

- `git archive HEAD` extracted into a directory with no ariadne sibling loads
  under `nvim --clean`: `require("parley")` and `setup({})` both succeed. Asserted
  by an automated test, not a manual check.
- A drift check fails when the committed vocabulary diverges from the `.cue`
  source, and is verified by deliberately editing the committed copy and watching
  it go red.
- `make test` runs to completion on that same bare extract.
- `git ls-files -s | awk '$1=="120000"'` lists no symlink whose target escapes the
  repository.
- Deleting the vendored JSON degrades the issue features with a message and
  leaves chat fully functional.

## Plan

- [ ] Vendor `construct/generated/vocabulary/issue.json`; add the regenerate-and-diff drift check.
- [ ] Make `issue_vocabulary.default()` non-fatal; guard `issues.lua:382`.
- [ ] Add a fresh-clone load spec that runs against an extracted archive.
- [ ] Real `Makefile` including `Makefile.parley`, `-include` ariadne overlay.
- [ ] Untrack maintainer-only symlinks; gitignore them; verify no escaping symlink remains.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as blocker B1 plus the
dev/user separation it exposed. The clean-clone failure was reproduced, and the
one-file fix was verified sufficient before this issue was written.

Note for whoever implements: the fix is deliberately *not* a repo split. #162
asked how isolated the two halves are; the coupling grep answers "concentrated in
`issues.lua` (82 refs), `vision.lua`, `super_repo.lua`, `neighborhood.lua`,
`artifact_ref.lua` and the two finders, with the chat core at 0-6 refs and
`init.lua` as the wiring hub". Decoupling at the load and registration boundary
is step one of a split either way, and is what the launch actually requires —
see #212.

## Revisions

### 2026-09-13 — deployment implementation design

Reason: operator asked to continue packaging toward an easily installed separate
Neovim profile. Delta: durable plan at
`workshop/plans/000208-fresh-clone-installability-plan.md` specifies unavailable
vocabulary behavior without invented lifecycle semantics; preserves existing
shell aliases/functions for sdlc; uses regenerate-and-content-compare drift
checks; repairs Plenary configuration and CI after untracking maintainer links.
The plan is prepared for approval; implementation has not started.

### 2026-09-13 — fresh-eyes plan review

The indirect finder cycle handler must refuse unchanged when vocabulary is
unavailable. CI needs explicit Go/CUE/exporter provisioning. The portable-root
Makefile needs ariadne#225: weave currently replaces real roots and follows
seed destination links. Record that prerequisite rather than ship a local
workaround. Updated durable plan is awaiting operator approval.

### 2026-09-13 — operator approval

Operator approved the reviewed #208 plan including ariadne#225 with “go ahead.”
The prerequisite is being implemented in its owning repo. Begin #208's runtime
work through change-code; portable maintainer integration waits for #225.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* Derived after plan-quality round 2 passed.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.30 impl=0.60
item: lua-neovim design=0.20 impl=0.40
item: cross-cutting-refactor design=0.10 impl=0.20
item: cross-repo-refactor-small design=0.04 impl=0.08
item: real-api-discovery design=0.00 impl=0.20
item: atlas-docs design=0.03 impl=0.06
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 2.494
```

Two focused Lua surfaces are the validated vocabulary/cache and its runtime
consumers: base design 1.5/1.0h ×0.2 for the accepted detailed plan, base impl
1.5/1.0h ×0.4 for v3.1. Cross-cutting build/archive/drift wiring uses 0.5h
design ×0.2 and 0.5h impl ×0.4; small peer-artifact integration uses 0.2/0.2h
similarly. Read-only external conformance uses 0.5h ×0.4. Docs use 0.15/0.15h
with the same design/impl transforms; one close review uses 0.1/0.4h. Design
subtotal 0.69h ×1.15 plus impl 1.70h = 2.4935h, rounded to 2.494h.

This is familiar Lua/shell work using vim.json, existing runners, real scratch
files, git archive, and the vocabulary exporter; no novel library is needed.
The upstream implementation of ariadne#225 is estimated in that issue, not
counted twice here. Calibration is flagged stale by estimate-source and remains
provisional, as directed by that source.
