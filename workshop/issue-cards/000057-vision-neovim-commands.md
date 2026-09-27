---
id: '000057'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision Neovim commands and integration

## Problem

Wire up `:ParleyVision*` commands, config, and picker UI.

Commands:
- `:ParleyVisionValidate` — run validation, show errors in quickfix <C-j>V
- `:ParleyVisionExportCsv [output]` — CSV export <C-j>ec
- `:ParleyVisionExportDot [output] [--root=node]` — DOT export <C-j>ed
- `:ParleyVisionShow` — float picker showing all initiatives (reuse issue finder pattern) <C-j>f
- `:ParleyVisionNew` — create a new project in current vision file <C-j>n

Config: `vision_dir` setting (parallel to `issues_dir`)

Parent: #52
