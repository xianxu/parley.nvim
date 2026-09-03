---
id: 000210
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
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

## Spec

Design a consent model for file mutation that keeps the agent useful. This is
explicitly not "flip `@all` back to `@readonly` and call it done" — the flip was
intentional and the capability has value.

- Decide the default posture for a *public* install, which may differ from the
  author's. Options to weigh: `@readonly` by default with a documented opt-in; or
  `@all` retained with a confirmation gate on first write per session or per file.
- Whatever the posture, a write must be *visible* before it lands: at minimum the
  path and a diff summary, through one seam both `edit_file`, `write_file` and
  `propose_edits` pass (`ARCH-DRY` — one gate, not three prompts).
- Give `edit_file` the same backup treatment as its siblings, or state why it must
  not have one.
- Surface write capability in the agent picker so a `@all` row is distinguishable
  from a read-only one.
- Bound the backup files: a retention rule and a gitignore entry.
- Write the missing behavioral tests for `edit_file` and `write_file` handlers.
  These are the destructive tools and they are the untested ones
  (`ARCH-PURE`: the edit computation is pure and directly testable; only the write
  is IO).

## Done when

- A file mutation initiated by the model cannot complete without either an
  explicit user confirmation or an explicit prior opt-in, and a test proves it by
  attempting one.
- `edit_file` and `write_file` handlers have behavioral tests covering success,
  no-match, and the backup path; each has been seen red.
- The agent picker distinguishes write-capable rows.
- Backup files have a bounded retention and are gitignored.
- The chosen default posture is recorded with its reasoning, so #157's flip is
  not silently reversed.

## Plan

- [ ] Decide and record the public default posture (revisits #157).
- [ ] Single confirmation/preview seam covering all three write tools.
- [ ] Backup for `edit_file`; retention rule + gitignore for `.parley-backup.*`.
- [ ] Write-capability affordance in the agent picker.
- [ ] Behavioral tests for `edit_file` and `write_file`, each seen red.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as blocker B3, kept
separate from #209 because it needs a design decision rather than a default flip,
and because it reopens a deliberate choice made in #157.
