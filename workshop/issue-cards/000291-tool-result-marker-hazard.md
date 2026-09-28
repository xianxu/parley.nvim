---
id: 000291
status: working
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
github_issue:
started: 2026-09-27T17:15:59-07:00
---

# Close the column-0 marker hazard in tool results (ls/find/stderr)

## Problem

A column-0 structural marker (`💬:`, `🔧:`, `📎:` …) inside a tool result ends
the result's body early (`fence.lua:148-154`), so a well-formed chat can parse
as a forked or truncated answer. Producers prevent this by prefixing their
lines (`read_file` `%5d  `, `grep`/`ack` `-H`, `chat_history_search`
`label/path:line:`), but two exceptions are recorded and deliberately
accepted (`atlas/providers/tool_use.md:283-301`, `fence.lua` comment):
- `ls`/`find` echo paths, so a file *named* `💬: notes.md` emits a marker;
- `grep`/`ack`/`ls`/`find` splice raw stderr after a prefixed first line.

#281 decided to keep tool payloads inline (design A), so this remaining gap
in inline results is worth closing instead of bounding.
