---
id: 0002
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
github_issue: 88
---

# chat tree copy paste

I want to make re-arranging chat question/answers easier. let's create copy/paste chat exchange easier.

1/ when cursor is on an exchange (either question or answer), would cut the current exchange, yank it into current clipboard.
2/ if there are visual selection, exchanges covering the selection would be yanked with , allowing yank of multiple exchanges.
3/ then in any other chat buffer, would paste the yanked text after the current exchange. current exchange defined as exchange the cursor is on.

## Done when

- ability to move chat exchange around

## Plan

### Design

Exchange = question line_start through answer line_end (or question line_end if no answer). We also need to include any trailing blank lines and branch lines that belong to the exchange, up to (but not including) the next exchange's question line_start.

Key bindings:
- `<C-g>X` — cut current exchange (normal) or exchanges overlapping visual selection (visual), store in clipboard
- `<C-g>V` — paste cut exchanges after the current exchange

Implementation: pure functions in a new `lua/parley/exchange_clipboard.lua` module, wired from init.lua.

### Tasks

- [x] Create `lua/parley/exchange_clipboard.lua` with pure functions
- [x] Add cut/paste commands in init.lua (`M.cmd.ExchangeCut`, `M.cmd.ExchangePaste`)
- [x] Add config shortcuts and keybindings (`<C-g>X`, `<C-g>V`)
- [x] Add keybindings to help display
- [x] Write unit tests for pure functions (14 tests, all passing)
- [x] Run lint + tests

## Log

### 2026-03-28

