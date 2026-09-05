---
id: 000219
status: open
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-05
estimate_hours:
---

# prepare_dir races on concurrent setup, failing specs intermittently

## Problem

Observed during #218's close: `make test` failed with

```
E739: Cannot create directory
  .../xdg/data/nvim/parley/persisted: file already exists
    helper.lua:554  prepare_dir
    vault.lua:34    setup
    init.lua:550    setup
```

`tests/unit/chat_slug_resolve_spec.lua` failed in the full run and **passed in
isolation**; an immediate re-run of the whole suite was green. The path in
question exists and is a directory, so nothing was corrupt.

`helper.lua:552-555` is check-then-act:

```lua
if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
end
```

Two spec processes calling `parley.setup()` at the same time both observe
`isdirectory == 0`, both call `mkdir`, and the loser raises. The guard is what
creates the window — it is a classic TOCTOU.

Not a #218 defect: nothing on that issue's diff is on this path. Filed rather
than dismissed as a flake, because "re-run until green" is how a real race gets
normalised.

## Spec

Make directory creation idempotent rather than guarded. `pcall` the `mkdir` and
re-check `isdirectory` afterwards, so a concurrent creator is indistinguishable
from success; only a path that is genuinely not a directory afterwards is an
error.

Sweep the class, not this call: any check-then-act around `mkdir`/`writefile` in
`lua/` has the same shape. `helper.prepare_dir` is the shared seam most callers
already use — the finding is whether any caller bypasses it.

## Done when

- concurrent `setup()` cannot raise E739
- a path that exists as a FILE where a directory is needed still errors, loudly
- the enumeration of check-then-act `mkdir` sites in `lua/` is recorded, and
  each either routes through `prepare_dir` or says why not

## Plan

- [ ] Enumerate check-then-act `mkdir` sites in `lua/`
- [ ] Make `prepare_dir` idempotent; keep the file-in-the-way case an error
- [ ] Test: two calls racing the same path both succeed; a file at the path fails
- [ ] Route or justify each other site

## Log

### 2026-09-05

Surfaced by #218's close run. Frequency unknown — one occurrence in roughly a
dozen full-suite runs this session.
