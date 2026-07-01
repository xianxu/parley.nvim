---
id: 000159
status: working
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.63
started: 2026-07-01T10:07:50-07:00
---

# use TAB for switching filter for chat finder

That's a more natural key binding. it should function like <C-a> when chat finder is open. 

## Problem

The chat finder's "filter" is a **recency** cycle (time windows → "All"), driven
bidirectionally: `<C-a>` = `next_recency` (move left), `<C-s>` = `previous_recency`
(move right), both via `_cycle_chat_finder_recency`. The user wants `<Tab>` to
cycle the filter like `<C-a>` — the chat-finder analog of #158's IssueFinder
`<Tab>`. Because this finder is **bidirectional**, the natural completion is
`<Tab>` = forward (like `<C-a>`) **and** `<S-Tab>` = back (like `<C-s>`) — the
idiomatic Tab/Shift-Tab pair — keeping `<C-a>`/`<C-s>` for back-compat.

## Spec

**`chat_finder.lua`:** the two recency mapping handlers (`:919-955`) are
near-identical — differing only by direction (`next_recency`→"previous",
`previous_recency`→"next"). DRY-refactor them into one `make_recency_cycle(direction)`
factory (ARCH-DRY) producing `recency_left_fn` ("previous", for `<C-a>`/`<Tab>`)
and `recency_right_fn` ("next", for `<C-s>`/`<S-Tab>`). Register each fn under
**both** its `<C-*>` key and its Tab key. Preserve the existing (counterintuitive
but intentional) direction mapping exactly. Header (`:680-683`) surfaces the
natural keys (`<Tab>`/`<S-Tab>`) via the new shortcuts.

`<Tab>`/`<S-Tab>` bind cleanly: same `float_picker` (`imap_p` + `on_key`),
`reserved_keys` only `<CR>`/`<Esc>`, no finder mapping uses `<C-i>`. `<Tab>` is
the guaranteed key; `<S-Tab>` is best-effort (some terminals) — `<C-s>` remains
as the reliable fallback.

**Config (`config.lua:489`):** add `chat_finder_mappings.cycle_filter =
{ modes={n,i,v,x}, shortcut = "<Tab>" }` and `cycle_filter_prev = { …,
shortcut = "<S-Tab>" }`; `next_recency`/`previous_recency` stay.

**Help + docs:** `keybinding_registry.lua` — add `cf_cycle_filter` (`<Tab>`,
desc "Cycle recency window left") + `cf_cycle_filter_prev` (`<S-Tab>`, "…right"),
mirroring `cf_next_recency`/`cf_prev_recency`. `keybindings_spec.lua` chat_finder
test — add `<Tab>`/`<S-Tab>` assertions. Update atlas (`ui/pickers.md` if it
details the recency cycle).

The pure `cycle_finder_recency` logic is untouched, so `chat_finder_logic_spec`
stays green. (Note: the `<Tab>`/`<S-Tab>` cycle glue lives inside `M.open`, so
it's manual-verify — same as #158's cycle handler; the registry help wiring is
unit-tested.)

## Done when

- `<Tab>` cycles the chat-finder recency filter like `<C-a>` (forward), `<S-Tab>`
  like `<C-s>` (back); `<C-a>`/`<C-s>` still work; header shows the Tab keys.
- The two recency handlers are one factory (no duplicated bodies — ARCH-DRY).
- `keybinding_registry` + `keybindings_spec` reflect the `<Tab>`/`<S-Tab>`
  bindings and stay green; atlas updated.
- Full suite green; lint clean.

## Plan

- [x] `chat_finder.lua`: extract `make_recency_cycle` factory; register
      `recency_left_fn` under `<C-a>` + `<Tab>`, `recency_right_fn` under `<C-s>`
      + `<S-Tab>`; add `cycle_filter`/`cycle_filter_prev` shortcut locals; header
      shows the Tab keys.
- [x] `config.lua`: add `cycle_filter` (`<Tab>`) + `cycle_filter_prev` (`<S-Tab>`).
- [x] `keybinding_registry.lua`: add `cf_cycle_filter` + `cf_cycle_filter_prev`.
- [x] `keybindings_spec.lua`: assert `<Tab>`/`<S-Tab>` in the chat_finder help.
- [x] `chat_finder_logic_spec.lua` (touchpoint the spec missed): it pins the
      header title + the mapping list by index — updated the 4 title assertions
      to `<Tab>/<S-Tab>` and the index-key assertions to the new order
      (`[5]=<Tab>, [6]=<C-s>, [7]=<S-Tab>`).
- [x] Atlas: `ui/pickers.md` documents the chat finder at feature-level with no
      per-key line (the recency keys were never in the atlas — only #158's issue
      finder has per-key detail), so no atlas edit — key source of truth is the
      keybinding registry (updated). `--no-atlas` at close.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: lua-neovim       design=0.2 impl=0.3
item: milestone-review design=0.0 impl=0.1
total: 0.63
```

`lua-neovim` (focused finder change, smaller than #158 — no state-model change,
just a DRY-refactor + 2 key bindings + config/registry/test/atlas): design 1–3 ×
0.2 spec discount → ~0.2; impl 0.5–1.5 (v2) × 0.4 → ~0.3. Single-pass
`milestone-review` ~0.1. +15% design buffer on ~0.2.

> *Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-01

Filed by the user (stub, sibling to #158). Investigated: chat-finder filter is
the **recency** cycle — `<C-a>`=`next_recency`/`<C-s>`=`previous_recency`
(`chat_finder.lua:549-550`), handlers at `:919-955` (near-identical, direction
only), config at `config.lua:489`, registry at `keybinding_registry.lua:718-735`,
help asserted at `keybindings_spec.lua:51-56`. Bidirectional → adding both
`<Tab>` (fwd) and `<S-Tab>` (back) as the natural Tab pair.

**Implemented.** DRY factory `make_recency_cycle(direction)` replaces the two
near-identical inline handlers; `<C-a>`/`<Tab>` → left, `<C-s>`/`<S-Tab>` → right
(direction mapping preserved exactly). Config + registry + help test updated. One
touchpoint the spec under-scoped: `chat_finder_logic_spec.lua` pins the header
title AND the mapping list *by index* — my header change (`<C-a>/<C-s>` →
`<Tab>/<S-Tab>`) and the 2 inserted mappings shifted both, caught by the full
suite; updated the 4 title assertions + the index-key assertions. `keybindings_spec`
20/20, `chat_finder_logic_spec` 34/34, lint clean.

**Manual verification (interactive keypress is async float-picker glue in `M.open`,
same as #158):** open `:ParleyChatFinder` (`<C-g>f`) → `<Tab>` cycles the recency
filter forward (like `<C-a>`), `<S-Tab>` backward (like `<C-s>`); `<C-a>`/`<C-s>`
still work; title reads `Chat Files (<label>  <Tab>/<S-Tab>: cycle)`.
