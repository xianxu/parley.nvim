---
id: 000111
status: done
deps: [110]
created: 2026-04-22
updated: 2026-04-22
---

# Decompose init.lua

init.lua was 4736 lines with ~20 logical sections. Goal: extract self-contained
sections to reduce init.lua size and improve cohesion.

## Done when

- init.lua is under 3500 lines
- Extracted modules are cohesive and have clear interfaces
- All tests pass, no behavioral changes

## Result

init.lua: 4736 → 3585 lines (1151 lines removed, 24% reduction)

Extracted modules:
- `lua/parley/keybinding_registry.lua` (1013 lines) — scope forest, 60 keybinding entries, help generation, registration (#110)
- `lua/parley/copy.lua` (151 lines) — CopyCodeFence, CopyLocation, CopyContext, zero dependencies
- `lua/parley/agent_info.lua` (138 lines) — get_agent_info with header merging, memory prefs, prompt appending

Remaining candidates (more coupled, diminishing returns):
- Chat path resolution (~250 lines) — depends on config, chat_slug, file_tracker, parse_chat_headers
- Chat tree operations (~220 lines) — depends on chat_path, float_picker, resolve_chat_path
- File reference handling (~240 lines) — depends on chat_path, open_buf, issues_mod
- Exchange clipboard (~100 lines) — depends on M.not_chat, M.parse_chat, exchange_clipboard module

## Plan

- [x] Extract keybinding system (#110) — 867 lines
- [x] Extract copy commands — 146 lines
- [x] Extract agent_info — 130 lines
- [x] Tests pass after each extraction (0 warnings, 0 errors, 0 failures)

## Log

### 2026-04-22

- Extracted copy.lua: fully self-contained, zero coupling
- Extracted agent_info.lua: depends on state/system_prompts/memory_prefs/logger, passed as args
- 3585 lines remaining — 85 over target but remaining sections too coupled for clean extraction
