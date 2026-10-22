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
flow: {kind: quick, provenance: inferred, spec: "ddcc7221", done: "f5e0d899"}
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

- [x] Review the [shared-deadline plan](../plans/000410-pending-lookup-admission-plan.md) with the TL before code.
- [x] Native red/green pending-lookup ordering, exact incarnation/witness scope, and residual acquisition deadline through late attachment.
- [x] Implement and verify the regression surface on both runtimes, counted 4/8-entry costs, disposable Couch conformance and indexed docs; prepare the recorded suite and TL-directed live acceptance. SDLC close owns fresh-context review; the recorded pass and live outcome remain mandatory before landing, tracked in the Log below.

## Log

Filed from #408 after TL approval a15354ef: use the existing pending lookup within the same 500 ms bound if small, otherwise document #408's boundary and file this follow-up. Investigation found completion ownership spans agentic_document.adopt -> session_sync.attach -> insert acquisition, while the current synchronous acquire seam owns its fixed 500 ms budget; a superficial wait can run a nested full acquire after consuming the lookup budget. This needs an explicit shared-deadline design rather than an extra wait in #408.

### 2026-10-22 — claimed and planned; awaiting TL

Read #408's landed owner/refusal/reload history and current S1 adoption, session-sync acquisition dispatcher and Couch process seam. The proposed ephemeral entry scope carries one absolute deadline through callback/late attachment and permits one acquire attempt; #408's private operator_admission remains the sole lock/history owner (ARCH-DRY/STATE). No producer protocol or failure policy changes. Exact witness/incarnation checks reject stale handoffs. Plan includes native queued-input races, timed pending fallback, late edit reconciliation and 4/8-entry counted costs.

Startup refreshed inherited tooling and produced an unrelated `.github/workflows/merge-check.yml` grep/SIGPIPE fix. Preserved that generated delta in stash `410: preserve weave-generated workflow delta before planning`; it is excluded from issue changes and no local-gates configuration is being shipped here. Planning branch created by `sdlc start-plan`. No code or tests edited; no stage or suite running. Next: TL review of committed durable plan before change-code.

### 2026-10-22 — approved implementation checkpoint

Verified submitted TL approval a1825097; change-code passed quick flow. Couch deadline seam delegated as bounded work: red 20 pass/5 expected fail/0 errors, green 25 pass/0 fail/0 errors; logs `/Volumes/TestScratch/parley-410-couch-2qky079j/`. Native initial red 142 pass/3 expected fail/0 errors, clean process census (`/tmp/parley-410-native-red.log`). The first native implementation exposed Normal-mode reporting during InsertEnter and a timeout-only wait overrun to 14889 ms. Explicit scope insert intent and a monotonic predicate restore confirmed first-edit freshness and a measured 500.25 ms fallback. Focused diagnostic snapshot: 11 pass/0 fail/0 errors, clean census (`/tmp/parley-410-focus-deadline.log`); corrected test use of actual S1 buffer numbers. No operator history policy was changed.

Current full native run `/tmp/parley-410-native-final.log` includes new 4/8-entry process/read counters; both count cases have passed, run still active. No recorded suite, PR or stage yet. Next: finish native verification, operator-runtime and mapped/architecture/lint checks, disposable conformance, then push and recorded suite/live acceptance through TL. Plan Revision records the native findings.

### 2026-10-22 — corrections verified on both runtimes; suite next

Preferred full native file completed 153/0/0. Operator 0.11.7 full native run was 151/2/0: one in-scope late-autosaved baseline defect and one independent #408 o-retry refusal assertion. Adoption now passes the observed baseline into attach before automatic insert acquisition. A new saved-normal-edit-before-insert case also pins the original baseline. Existing operator_admission transitions are unchanged.

The broad map completed 58 files, 840 passing cases, three architecture failures: two plan-table inventories and one synchronous spawn classification. Corrected individual public-symbol rows and preserved the direct synchronous spawn/wait expression. Final focused corrections on EACH runtime pass 80 cases, zero failures/errors (`/tmp/parley-410-corrections-preferred.log`, `/tmp/parley-410-corrections-operator.log`), including new native cases, residual process unit tests and affected guards. All other broad checks passed. Final lint: zero warnings/errors in 822 files. Isolated real/fake registry/operator conformance and corrupted-fake negative control pass (`/tmp/parley-410-conformance-real.log`, `-fake.log`).

TL 97e1636a instructed filing the unrelated retry case separately and not blocking #410 on it; filed unclaimed #412 with the failure, isolated 200 ms delayed-producer pass, command durations and explicitly missing failure-time load. Current sampled load was 20.35/33.58/39.16, not a retrospective failure measurement. Diagnostic assertion now records native mode/notifications on recurrence; oracle unchanged. Typed Lua registry support is ariadne#556. Only this exact failure has TL authorization for one evidenced recorded-suite rerun.

PR #333 exists. TL 828e035c authorized a disposable copied operator-profile live check only AFTER review and suite pass. Any :0 stage must wait for #411's operator stage to clear and requires another TL ask before staging. No stage held. Next: commit/push corrections, recorded suite on that exact head, SDLC close review, then authorized live acceptance. Do not restart while the recorded check is queued/running.

Recorded suite lease-1901041664, attempt 1f75cea859f261b4e87927ca0d433a4f, is queued normally on pushed 11c41b7b. Initial FIFO position 14 behind two Pair runs. Log: common Git dir `sdlc/test-stats/inflight/1f75cea859f261b4e87927ca0d433a4f/run.log`. Per tl-worker's explicit overlap rule, the close review may run while this check is queued; a passing recorded final-code suite still precedes live acceptance and landing. No duplicate runner, stage or restart.

## Revisions

### 2026-10-22 — distinguish implementation checklist from landing evidence

The final Plan checkbox originally combined implemented tests/docs with the recorded suite and live check. Clarified it as completed implementation/verification preparation so SDLC can run its single close review while the suite waits, as tl-worker explicitly permits. The mandatory recorded pass and post-review/suite live acceptance are retained above and in the Log; no requirement is waived or represented as already passed.
