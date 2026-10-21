---
id: 000406
status: open
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'db87faaf74a6182d7b77ddc600b12b4569922888' # card fields mirrored from issue-cards; edit via sdlc
---

# MarkdownPreview throws 'Cannot read properties of undefined (reading refreshPage)' on session.md and side docs

## Problem

On 10-20 at 21:33 the operator's MarkdownPreview stopped working on the hub session file and side docs (in
`~/workspace/ops/session.md` and `session.side/*.md`), with the error in the nvim message line:
`TypeError: Cannot read properties of undefined (reading 'refreshPage')`. Screenshot:
`ops/assets/session/2026-10-20.21-33-40.545.png`. Those files are written frequently from outside nvim (Couch
session-sync writes by the TL), and they moved today from `teams/devinfra/tl-status-*.md` to the repo root
(`session.md`, `session.side/`, ariadne#504). parley.nvim also had several landings today.

## Spec

- Reproduce: open `session.md` with MarkdownPreview running, write the file from outside (session-sync style), and
  check whether the preview server's refresh hits a buffer or page it doesn't know (the error comes from the
  markdown-preview server's `refreshPage` on an undefined client or page).
- Find whether parley (or its session-sync reload path) triggers the preview refresh for a buffer whose preview page
  isn't registered (for example after an external reload or the path change), and fix it so the preview keeps
  updating, or at least never throws.

## Done when

- A regression reproduces the TypeError before the fix and passes after; the operator's preview of session.md and a
  side doc updates live after an external write.

## Plan

- [ ]

## Log

### 2026-10-20
