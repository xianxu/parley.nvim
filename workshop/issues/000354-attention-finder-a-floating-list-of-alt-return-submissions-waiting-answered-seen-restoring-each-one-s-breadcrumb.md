---
id: 000354
status: open
deps: [parley.nvim#332]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '89fecb1a7d4752f84ea4ba02feb4517deef85c14' # card fields mirrored from issue-cards; edit via sdlc
---

# Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb

## Problem

The operator uses Alt+o and Alt+Return as an attention pipeline: read, comment, submit, move on. Nothing brings them
back when the agent answers a submitted file. Operator design, 2026-10-16 (ops QA
`teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`). Part of ops project universal-agent-input-interface.

## Spec

- **An attention finder:** a floating window (the chat finder's typeahead) listing every file submitted with
  Alt+Return, newest first.
- **Row state from the authorities, not mtimes:** Couch's ledger (a submit's owed event folded means the agent
  answered) and #332's submit receipt (content hash at submit). States: **waiting**, **answered** (highlighted), and
  **seen** (opened after the answer). Opening a row marks it seen.
- **Each entry stores the breadcrumb** (the per-file trail from the breadcrumb issue) at submit time; jumping from the
  finder restores that trail, so the tree stays intact.
- **One free Alt chord** opens it in Couch's nvim; the session file's winbar may show a count of answered-but-unseen.

## Done when

- Tests: entries appear on submit; state transitions (waiting, answered via a fold, seen on open); breadcrumb
  restored on jump; typeahead; then the operator's live check.

## Plan

- [ ]

## Log

### 2026-10-16
