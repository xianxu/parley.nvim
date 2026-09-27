---
id: 000210
status: open
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
github_issue:
---

# consent model for write-capable tools

## Problem

The shipped agent can modify files with no confirmation and effectively no test
coverage.

- The one shipped agent has `tools = { "@all" }` (`config.lua:226`); `@all`
  expands to include `kind = "write"` (`tools/init.lua:99-101`). Picking any live
  cliproxy model grants the same (`cliproxy_catalog.lua:238`), with no indication
  in the picker that the row is write-capable.
- **No confirmation prompt exists anywhere.** Grepping `confirm|vim.ui.select`
  across `lua/parley/tools/` returns nothing.
- `edit_file` has `needs_backup = false` and **zero behavioral tests** — no
  `tools_builtin_edit_file_spec.lua` exists. `write_file`'s handler is likewise
  untested; only registration shape is asserted.
- The tool loop runs up to 42 unattended iterations (`defaults.lua:71`).
- `.parley-backup.<n>` files accumulate unboundedly (`tools/backup.lua:17-33`),
  are never cleaned, and are not gitignored.

The `elevated` mechanism is the codebase's one real write guard, and it
constrains skills only — the default agent's `@all` bypasses it entirely.

The `@all` default was a deliberate flip from `@readonly` (#157) and is pinned by
a canary test, so this is a decision to revisit, not an oversight to correct.
