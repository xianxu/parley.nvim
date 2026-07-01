---
id: 000158
status: working
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.8
started: 2026-07-01T09:45:31-07:00
---

# bind TAB in issue tracker to switch filter criteria

That's a more natural key binding. it should function like <C-a> when issue finder is open. 

also change the 3 stop filter to 2: just all in workshop/issues and workshop/history

## Problem

The IssueFinder float picker cycles a **tri-state** `view_mode` on `<C-a>`
(`toggle_done`): `all → active → all+history` (`% 3`, added in #152). Two asks:

1. **`<Tab>` is the more natural key** to cycle the view — bind it to the same
   action as `<C-a>` (keep `<C-a>` too; additive, non-breaking).
2. **Collapse the 3 states to 2**: just **`issues`** (everything in
   `workshop/issues/`) and **`history`** (the archived items in
   `workshop/history/`). Drop the intermediate `active` filter (#152's
   "hide done" step) — done items simply show in the `issues` view.

## Spec

**Pure view-mode logic (`issue_finder.lua`, unit-tested — ARCH-PURE):**

- `VIEW_LABELS = { [0] = "issues", [1] = "history" }`.
- `includes_history(view_mode)` = `view_mode == 1` (only the history view scans
  `workshop/history/`).
- `filter_for_view` partitions by the `archived` flag: view 0 keeps
  **non-archived** items (issues dir), view 1 keeps **archived** items (history).
  Normalize `issue.archived == true` so a nil flag counts as non-archived. No
  mutation of the input list.
- Cycle is `(view_mode + 1) % 2`; read as `(stored or 0) % 2` so any stale
  value (e.g. a `2` left in in-memory state) self-heals to a valid view.

**Keybinding (`<Tab>` alongside `<C-a>`):**

- New config default `issue_finder_mappings.cycle_view = { modes = {n,i,v,x},
  shortcut = "<Tab>" }`; `<C-a>` (`toggle_done`) stays for back-compat.
- Extract the cycle action into one local fn and register it under **both**
  shortcuts (ARCH-DRY — one handler, two keys).
- `<Tab>` binds cleanly: `float_picker` applies extra mappings via `imap_p`
  (insert-mode `vim.keymap.set`) + `on_key`; `reserved_keys` is only
  `<CR>`/`<Esc>`, and no finder mapping uses `<C-i>` (the `<Tab>` alias), so no
  conflict. (The old "insert-mode float → only `<C-*>`" lesson predates this
  picker.)
- Header label surfaces the natural key: `Issues (<label>  <Tab>: cycle view)`.

**Help + docs:** update `keybinding_registry.lua` `if_toggle_done` desc →
"Cycle view (issues/history)" and add an `if_cycle_view` entry for `<Tab>`;
update the atlas (`ui/keybindings.md`, `issues/issue-management.md`) to the
2-state model.

Supersedes #152's tri-state (the `active` quick-filter is intentionally removed
per the user's request).

## Done when

- `<Tab>` and `<C-a>` both cycle the IssueFinder view; header shows `<Tab>`.
- Only two views exist — `issues` (all of `workshop/issues/`, incl. done-not-
  archived) and `history` (archived) — verified by `filter_for_view` /
  `includes_history` / `VIEW_LABELS` unit tests updated to the 2-state model.
- `keybinding_registry` + atlas reflect the 2-state cycle and the `<Tab>` key;
  `keybindings_spec` (if it asserts the finder entries) stays green.
- Full suite green; lint clean.

## Plan

- [x] `issue_finder.lua`: rewrite VIEW_LABELS / includes_history /
      filter_for_view for 2 states; clamp `view_mode % 2`; `% 3 → % 2`; extract
      `cycle_view_fn` + register under `<Tab>` and `<C-a>`; header interpolates
      the `cycle_view` shortcut (not hardcoded).
- [x] `config.lua`: add `issue_finder_mappings.cycle_view = <Tab>`.
- [x] `keybinding_registry.lua`: reword `if_toggle_done`; add `if_cycle_view`.
- [x] Rewrite `tests/unit/issue_finder_spec.lua` for the 2-state model
      (+ nil-archived case; scrubbed the #152 tri-state comments).
- [x] `tests/unit/keybindings_spec.lua`: update the `<C-a>` desc + add a `<Tab>`
      assertion (plan-quality Important — the test asserts the finder entries).
- [x] Update atlas (`issues/issue-management.md`; `ui/keybindings.md` has no
      per-view detail line, no edit needed); full suite + lint green.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: lua-neovim       design=0.3 impl=0.4
item: milestone-review design=0.0 impl=0.1
total: 0.8
```

`lua-neovim` (single, focused finder change): design 1–3 × 0.2 spec discount
(this spec pre-resolves the state model, keybind mechanism, and all touchpoints)
→ ~0.3; impl 0.5–1.5 (v2) × 0.4 (v3.1) → ~0.4. Single-pass `milestone-review`
~0.1. +15% design buffer on ~0.3.

> *Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-01

Filed by the user (stub, preserved from the #157 branch cleanup). Investigated
all touchpoints before speccing: cycle lives in `issue_finder.lua:291`
(`% 3`), `<C-a>` = `toggle_done` mapping (`:289`), config defaults at
`config.lua:547`, help entries at `keybinding_registry.lua:793-819`. `<Tab>`
confirmed bindable (float_picker `imap_p` + `on_key`; reserved = `<CR>`/`<Esc>`
only).

**Implemented.** All six touchpoints done (see Plan). Pure logic:
`issue_finder_spec.lua` 6/6; help wiring: `keybindings_spec.lua` 20/20 (asserts
both `<Tab>` and `<C-a>` show "Cycle view (issues/history)"); full `make test`
suite green; lint clean. The plan-quality Important (keybindings_spec would break
on the desc reword) was folded in; header interpolates `cycle_view_shortcut`
(ARCH-DRY, not hardcoded); test comments scrubbed of the tri-state model.

**Manual verification (the interactive keypress can't run headlessly — it's async
float-picker UI, but rides the identical `imap_p` path as the working
`<C-a>`/`<C-d>`/`<C-s>` mappings):** open `:ParleyIssueFinder` (`<C-y>f`) →
press `<Tab>` → view cycles `issues` ↔ `history` (badge in the title flips,
archived items appear only in `history`); `<C-a>` does the same; the title reads
`Issues (<view>  <Tab>: cycle view)`.
