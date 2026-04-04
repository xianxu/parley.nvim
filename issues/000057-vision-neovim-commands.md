---
id: 000057
status: done
deps: [54, 55, 56]
created: 2026-04-04
updated: 2026-04-04
---

# vision Neovim commands and integration

Wire up `:ParleyVision*` commands, config, and picker UI.

Commands:
- `:ParleyVisionValidate` — run validation, show errors in quickfix <C-j>V
- `:ParleyVisionExportCsv [output]` — CSV export <C-j>ec
- `:ParleyVisionExportDot [output] [--root=node]` — DOT export <C-j>ed
- `:ParleyVisionShow` — float picker showing all initiatives (reuse issue finder pattern) <C-j>f
- `:ParleyVisionNew` — create a new project in current vision file <C-j>n

Config: `vision_dir` setting (parallel to `issues_dir`)

Parent: #52

## Done when

- All commands registered and functional
- `vision_dir` config option works
- Validation errors shown clearly to user
- Picker shows initiatives with name, type, size, quarter
- Integration tests pass

## Plan

- [x] Add `vision_dir` to config in `lua/parley/config.lua`
- [x] Register commands in `lua/parley/init.lua` (auto-registered via M.cmd table)
- [x] Implement command handlers: `cmd_validate`, `cmd_export_csv`, `cmd_export_dot`, `cmd_new`
- [x] Register shortcuts: `<C-j>V`, `<C-j>ec`, `<C-j>ed`, `<C-j>n`
- [x] Implement float picker for `:ParleyVisionShow` (`<C-j>f`) — done in #59

## Log

### 2026-04-04

