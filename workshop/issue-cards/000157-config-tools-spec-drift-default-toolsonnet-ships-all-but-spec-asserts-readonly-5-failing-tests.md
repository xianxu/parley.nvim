---
id: '000157'
status: done
started: 2026-07-01T08:34:35-07:00
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.3
actual_hours: 0.31
---

# config_tools_spec drift: default ToolSonnet ships @all but spec asserts @readonly (5 failing tests)

## Problem

`tests/unit/config_tools_spec.lua` fails **5 tests** deterministically (in
isolation and in the full suite). The shipped default config
(`lua/parley/config.lua:222,246`) sets both `ToolSonnet*` and `ToolSonnet` to
`tools = { "@all" }` with the comment *"Swap @readonly → @all to also allow
edit/write"* — an intentional config change — but `config_tools_spec.lua` was
never refit. It still asserts:

- `get_agent("ToolSonnet").tools == { "@readonly" }` (`:149`, `:198`),
- and, in the full wiring chain, that `edit_file` / `write_file` are **absent**
  (read-only agent) in the resolved payload (`:232`, `:258`).

With the current `@all` default these expectations are wrong, so the suite is red
on a point unrelated to the feature under test. Discovered while landing #155
(verified unrelated to it via `git stash` — #155 touches only message emission).
