---
id: '000247'
status: done
started: 2026-09-13T14:26:40-07:00
created: 2026-09-13
updated: 2026-09-14
estimate_hours: 4.159
actual_hours: 11.92
---

# Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM

## Problem

The `parley-packaging` project's end state: `brew install xianxu/parley/parley`
followed by `parley` starts a working chat for someone who has never used
Neovim, with Claude, Codex and Gemini available through the managed cliproxy
and no API key typed.
