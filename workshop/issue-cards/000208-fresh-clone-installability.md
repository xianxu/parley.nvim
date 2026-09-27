---
id: '000208'
status: done
started: 2026-09-13T12:19:41-07:00
created: 2026-09-02
updated: 2026-09-13
estimate_hours: 2.494
actual_hours: 1.81
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
