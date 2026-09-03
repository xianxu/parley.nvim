---
id: 000208
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
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
