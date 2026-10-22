---
id: 000410
status: working
deps: [parley.nvim#408]
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'e9210df141ad1832e3258ba1b5fb35ffaed5733d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T11:48:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- [ ] Review the [shared-deadline plan](../plans/000410-pending-lookup-admission-plan.md) with the TL before code.
- [ ] Native red/green pending-lookup ordering, exact incarnation/witness scope, and residual acquisition deadline through late attachment.
- [ ] Both-runtime regressions, counted 4/8-entry costs, disposable Couch conformance, indexed docs, recorded suite and TL-directed live check; SDLC close owns fresh-context review.

## Log

Filed from #408 after TL approval a15354ef: use the existing pending lookup within the same 500 ms bound if small, otherwise document #408's boundary and file this follow-up. Investigation found completion ownership spans agentic_document.adopt -> session_sync.attach -> insert acquisition, while the current synchronous acquire seam owns its fixed 500 ms budget; a superficial wait can run a nested full acquire after consuming the lookup budget. This needs an explicit shared-deadline design rather than an extra wait in #408.

### 2026-10-22 — claimed and planned; awaiting TL

Read #408's landed owner/refusal/reload history and current S1 adoption, session-sync acquisition dispatcher and Couch process seam. The proposed ephemeral entry scope carries one absolute deadline through callback/late attachment and permits one acquire attempt; #408's private operator_admission remains the sole lock/history owner (ARCH-DRY/STATE). No producer protocol or failure policy changes. Exact witness/incarnation checks reject stale handoffs. Plan includes native queued-input races, timed pending fallback, late edit reconciliation and 4/8-entry counted costs.

Startup refreshed inherited tooling and produced an unrelated `.github/workflows/merge-check.yml` grep/SIGPIPE fix. Preserved that generated delta in stash `410: preserve weave-generated workflow delta before planning`; it is excluded from issue changes and no local-gates configuration is being shipped here. Planning branch created by `sdlc start-plan`. No code or tests edited; no stage or suite running. Next: TL review of committed durable plan before change-code.
