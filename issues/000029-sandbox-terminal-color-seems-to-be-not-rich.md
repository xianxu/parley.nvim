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

- [x] Check current TERM and COLORTERM env vars inside sandbox
- [x] Identify correct values (e.g. `xterm-256color`, `COLORTERM=truecolor`)
- [x] Update `.openshell/Dockerfile` or `.openshell/dotfiles/zshrc` with fix
- [ ] Rebuild sandbox and verify colors

## Log

### 2026-03-30

**Finding**: Neither `TERM` nor `COLORTERM` were set anywhere in the sandbox config — Dockerfile, zshrc, or overlay. The container was relying on whatever the host/OpenShell runtime provided, which was likely `dumb` or `linux` (no 256-color support).

**Fix**:
- `Dockerfile`: Added `ENV TERM=xterm-256color` and `ENV COLORTERM=truecolor` near the top so all build steps and runtime have proper color support
- `zshrc`: Added fallback exports (`${TERM:-xterm-256color}`, `${COLORTERM:-truecolor}`) so colors work even if the container runtime strips ENV vars

**Next**: Rebuild sandbox and verify colors render correctly in zsh prompt, nvim (moonfly colorscheme), bat, fzf, etc.

