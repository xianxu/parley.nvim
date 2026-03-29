---
id: 000029
status: open
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# sandbox terminal color seems to be not rich

check terminal TTY setting, enable 256 or higher color

## Done when

- Sandbox terminal supports 256+ colors (TERM/COLORTERM set correctly)
- Colors render richly in zsh prompt, nvim, and CLI tools (bat, fzf, etc.)

## Plan

- [ ] Check current TERM and COLORTERM env vars inside sandbox
- [ ] Identify correct values (e.g. `xterm-256color`, `COLORTERM=truecolor`)
- [ ] Update `.openshell/Dockerfile` or `.openshell/dotfiles/zshrc` with fix
- [ ] Rebuild sandbox and verify colors

## Log

### 2026-03-29

