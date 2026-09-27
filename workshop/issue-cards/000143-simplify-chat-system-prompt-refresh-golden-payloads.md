---
id: '000143'
status: done
started: 2026-06-25T21:32:15-07:00
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 0.25
actual_hours: 0.25
---

# simplify chat system prompt; refresh golden payloads

## Problem

The chat system prompt (`M.chat_system_prompt`, `lua/parley/defaults.lua`) was
simplified — the explicit `🧠:` thinking-block protocol (marker, `[END]`, the
reserved-marker note) was dropped. The 7 golden payloads embed the system prompt
verbatim, so they no longer match `build_payload`'s output and
`tests/unit/parley_harness_golden_spec.lua` fails 7/7 in the working tree.
