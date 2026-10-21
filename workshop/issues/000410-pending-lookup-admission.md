---
id: 000410
status: open
deps: [parley.nvim#408]
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'bce16d45ba1b8900f0db881eccf81bc291e3b430' # card fields mirrored from issue-cards; edit via sdlc
---

# Bound insert admission across pending registration lookup

## Problem

#408 fences insert admission after S1 has a confirmed registered identity. Just after opening a file with no cached identity, S1 may still be looking it up; edits in that unknown interval remain possible and are reconciled on attachment. The operator is most likely to meet that gap when immediately typing into a newly opened session file.

## Spec

On InsertEnter, if S1 already has a lookup pending for that exact buffer/incarnation, give that existing request a chance to finish within the same total 500 ms admission budget. Do not start a synchronous registration lookup for every Markdown file. A confirmed registration then uses #408's normal acquisition and freshness path, with only the remaining time in that shared budget. If lookup is still pending when the budget expires, retain today's editable unknown-period behavior and outstanding-edit reconciliation. Do not cancel the shared discovery request just because the input wait ended.

The wait must not recursively admit another acquire with a fresh 500 ms budget: S1's completion callback adopts the identity, and session_sync.attach currently acquires immediately if already inserting. One deadline must cover both modules, attachment and acquisition, without changing ordinary background discovery or unregistered-file input.

## Done when

- Native queued-input tests hold an existing lookup, complete it before the deadline, then race an external write against acquisition; first input follows confirmed protection and clean freshness.
- Lookup plus acquisition share a measured total 500 ms bound, including callback/late-attach nesting; no fresh per-stage deadline can exceed it.
- A lookup that remains pending permits today's unknown-period input after the bound, and later completion reconciles outstanding edits safely.
- A plain file with no pending lookup has no new blocking Couch request; stale buffer/incarnation completions cannot gate another buffer.
- Both supported Neovim versions pass, with the existing stateful Couch fake and disposable real-command conformance where applicable.

## Plan

## Log

Filed from #408 after TL approval a15354ef: use the existing pending lookup within the same 500 ms bound if small, otherwise document #408's boundary and file this follow-up. Investigation found completion ownership spans agentic_document.adopt -> session_sync.attach -> insert acquisition, while the current synchronous acquire seam owns its fixed 500 ms budget; a superficial wait can run a nested full acquire after consuming the lookup budget. This needs an explicit shared-deadline design rather than an extra wait in #408.
