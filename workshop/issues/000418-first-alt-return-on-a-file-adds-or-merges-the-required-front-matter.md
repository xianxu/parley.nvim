---
id: 000418
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '0e5b3344eda4694abc7300b5334d16f833951451' # card fields mirrored from issue-cards; edit via sdlc
---

# First Alt+Return on a file adds or merges the required front matter

## Problem

## Spec

Operator request (10-22): the **first time** the operator presses **Alt+Return** on a file (submitting it to the agent
in the same pair session), parley checks that the file has the front matter a submitted/registered document needs; if
it has none, parley adds it; if it already has front matter, parley **merges** the required fields into it (adding
missing keys, never overwriting or dropping the operator's existing keys or values).

- "Required" is whatever Couch's session-sync registration and the submit path need (today a plain side doc can be
  refused with "is not a session-sync file (frontmatter `type: session-sync`)"); derive the set from that contract,
  don't invent one. Where a value can't be inferred, leave the file unsubmitted and say which key is missing.
- Idempotent: later Alt+Returns on the same file change nothing if the fields are present.
- The front-matter edit is a normal buffer edit (undoable), done before the submit, and saved with the submit.
- Related: parley.nvim#410 (unregistered typed files show "not protected" until the first submit registers them).

## Done when

- Alt+Return on a file with no front matter adds the required fields and submits (test).
- Alt+Return on a file with partial front matter merges the missing fields, keeping existing keys and values exactly
  (test).
- A second Alt+Return makes no front-matter change (test).

## Plan

- [ ]

## Log

### 2026-10-22
