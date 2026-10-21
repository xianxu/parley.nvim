---
id: 000406
status: open
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
github_issue:
---

# MarkdownPreview throws 'Cannot read properties of undefined (reading refreshPage)' on session.md and side docs

## Problem

On 10-20 at 21:33 the operator's MarkdownPreview stopped working on the hub session file and side docs (in
`~/workspace/ops/session.md` and `session.side/*.md`), with the error in the nvim message line:
`TypeError: Cannot read properties of undefined (reading 'refreshPage')`. Screenshot:
`ops/assets/session/2026-10-20.21-33-40.545.png`. Those files are written frequently from outside nvim (Couch
session-sync writes by the TL), and they moved today from `teams/devinfra/tl-status-*.md` to the repo root
(`session.md`, `session.side/`, ariadne#504). parley.nvim also had several landings today.
