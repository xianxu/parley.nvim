---
id: '000219'
status: done
started: 2026-09-13T13:03:44-07:00
created: 2026-09-05
updated: 2026-09-13
estimate_hours: 0.988
actual_hours: N/A
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
