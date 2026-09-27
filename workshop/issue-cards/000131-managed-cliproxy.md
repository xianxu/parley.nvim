---
id: '000131'
status: done
created: 2026-06-12
updated: 2026-06-14
estimate_hours: 16
actual_hours: 11.81
---

# Manage cliproxyapi lifecycle + config

## Problem

Parley talks to `cliproxyapi` as a normal provider (`lua/parley/config.lua` →
`http://127.0.0.1:8317/v1/chat/completions`, dual OpenAI/Anthropic adapter in
`providers.lua`), but assumes the proxy is **already running and configured
out-of-band**. Today that means: `brew install`, `brew services start`, and
hand-editing config under `/opt/homebrew` — a path that can't live in the user's
version-controlled dotfiles (yadm). Setup friction + non-committable config +
manual lifecycle. Parley owns the client cleanly and owns *nothing* of the
proxy's binary / config / lifecycle. This issue closes that gap.
