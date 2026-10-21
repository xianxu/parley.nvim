---
id: 000405
status: open
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a9db70d645e5e0800969dc5addff506123c18e67' # card fields mirrored from issue-cards; edit via sdlc
---

# remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch

## Problem

Project remote-session (ops `teams/devinfra/projects/remote-session/`, operator-approved 10-20) makes the phone a
remote view of the live nvim buffer for each hub's session file and side docs. Couch needs to reach the nvim that has
the file open, without the operator starting nvim with special flags.

## Spec

- When parley attaches to a registered session file or side doc, it starts a private RPC server for that nvim
  (`serverstart()` on a per-file socket under a private runtime folder) and registers the address with Couch, the same
  way it reports submits; it unregisters on buffer wipe or nvim exit.
- Plain `nvim session.md` keeps working; no flag.
- If two nvims open the same file, the most recent registration wins and the other is told (parley already warns
  about a second editor on a locked file).
- Related: parley.nvim#404 (take the lock on entering insert mode) is the desktop half of "keyboard shown = locked".

## Done when

- Tests: attach registers an address, wipe and exit unregister, a second nvim supersedes the first; the socket is
  private (0700 folder).

## Plan

- [ ]

## Log

### 2026-10-20
