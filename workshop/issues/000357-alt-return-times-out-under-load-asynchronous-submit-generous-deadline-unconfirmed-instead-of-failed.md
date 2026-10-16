---
id: 000357
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '34626826fb4b332d699dbdc59ff5505173a49c99' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed

## Problem

Alt+Return times out under load. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.
- `document_registry` requests default to `timeout_ms` 2500, and `agentic_document`'s `bounded_request` blocks the editor in `vim.wait(2600)`.
- On a busy machine the couch CLI alone can take longer than that. The submit then fails as "Couch deadline exceeded", although it may still land.

## Spec

1. The submit is asynchronous. The editor never blocks in `vim.wait` for a Couch round trip, and the winbar shows "submitting…" meanwhile.
2. A generous deadline, about 15 s, configurable.
3. On the deadline the result is "unconfirmed", not "failed". Parley checks the receipt or the ledger for that submit before offering a resend, so the operator never double-submits. #332's dedup receipt helps here.
4. The other blocking waits get the same treatment, such as the 3000 ms move wait.

## Done when

- Tests with a slow fake Couch cover:
  - a submit that is slower than the old 2.6 s and still succeeds, with the editor not blocked meanwhile;
  - a deadline that ends unconfirmed and then resolves from the receipt, with no double submit;
  - the move wait under the same slow fake.
- After that, the operator's live check.

## Plan

- [ ]

## Log

### 2026-10-16
