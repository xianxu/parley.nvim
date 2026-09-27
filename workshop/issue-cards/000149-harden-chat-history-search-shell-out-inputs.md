---
id: '000149'
status: done
started: 2026-06-27T11:19:29-07:00
created: 2026-06-26
updated: 2026-06-27
estimate_hours: 1.5
actual_hours: 0.13
---

# Harden chat_history_search shell-out inputs

## Problem
The #144 boundary review found a pre-existing sibling injection surface in
`lua/parley/tools/builtin/chat_history_search.lua`.

Unlike the hardened `ls`/`grep`/`find`/`ack` tools, `chat_history_search` still
builds a shell string and runs `vim.fn.system(cmd)`. It quotes `glob`,
`pattern`, and root paths, but interpolates `before`, `after`, and `max_count`
with `tostring()` directly into the shell command. Since JSON schema integer
types are advisory at the LLM boundary, a crafted string such as
`before = "0; <cmd> #"` can become shell syntax.
