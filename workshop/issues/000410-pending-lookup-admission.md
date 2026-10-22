---
id: 000410
status: working
deps: [parley.nvim#408]
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours: 1.752
collaboration-mode: collaboration
card_mirror: 'ee380c1dd15e3f66ec0d9e1def52878a07689beb' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T11:48:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# Bound insert admission across pending registration lookup

## Problem

#408 fences insert admission after S1 has a confirmed registered identity. Just after opening a file with no cached identity, S1 may still be looking it up; edits in that unknown interval remain possible and are reconciled on attachment. The operator is most likely to meet that gap when immediately typing into a newly opened session file.

## Spec

On InsertEnter, if S1 already has a lookup pending for that exact buffer/incarnation, give that existing request a chance to finish within the same total 500 ms admission budget. Do not start a synchronous registration lookup for every Markdown file. A confirmed registration then uses #408's normal acquisition and freshness path, with only the remaining time in that shared budget. If lookup is still pending when the budget expires, retain today's editable unknown-period behavior and outstanding-edit reconciliation. Do not cancel the shared discovery request just because the input wait ended.

The wait must not recursively admit another acquire with a fresh 500 ms budget: S1's completion callback adopts the identity, and session_sync.attach currently acquires immediately if already inserting. One deadline must cover both modules, attachment and acquisition, without changing ordinary background discovery or unregistered-file input.

Operator-approved retirement revision (Couch 8f18c995): S1 owns admission from file opening and never starts a new tokenless turn, including on typed files with absent, pending or unavailable membership. Those typed files remain editable with a clear not-protected indication until registered; first submit registers. Outside S1, standalone legacy behavior stays unchanged. Existing old protection and move journals are finished/released explicitly through proven ownership or validated recovery, never swept or automatically converted. The active RETIRE plan supersedes the attempted dual-protocol handoff; its exact existing-lock/journal rule requires TL agreement before code and fresh plan-quality afterward.

## Done when

- Native queued-input tests hold an existing lookup, complete it before the deadline, then race an external write against acquisition; first input follows confirmed protection and clean freshness.
- Lookup plus acquisition share a measured total 500 ms bound, including callback/late-attach nesting; no fresh per-stage deadline can exceed it.
- A lookup that remains pending permits today's unknown-period input after the bound, and later completion reconciles outstanding edits safely.
- A plain file with no pending lookup has no new blocking Couch request; stale buffer/incarnation completions cannot gate another buffer.
- Both supported Neovim versions pass, with the existing stateful Couch fake and disposable real-command conformance where applicable.
- S1 owns admission before legacy attachment: no new tokenless lock on opening, edits, absence/unavailability completion or expired input scopes. Typed unregistered/unknown files retain a visible not-protected indication and first submit registers normally.
- Old live proof/history is preserved until explicit exact owned completion; unproven sidecars remain refused with owner-assisted recovery guidance. Existing v1/v2 journals retain validated forward recovery, and no new move uses tokenless protection as admission.
- Standalone editors outside S1 retain legacy locks, submit, unchanged-exit and undo behavior; no automatic sweep or new generic unlock is introduced.

## Plan

- [ ] Agree the active [RETIRE plan](../plans/000410-pending-lookup-admission-plan.md), especially old-lock/journal recovery, with the TL; clear fresh plan-quality before code.
- [ ] Replace the superseded handoff/deferred-write mechanism with S1-first ownership, one admission route and the not-protected presentation; prove retirement and compatibility through red/green tests.
- [ ] Verify both runtimes, full mapped regressions, counts/deadlines, guards, lint and conformance; recorded suite, fresh close review and authorized live acceptance remain required before landing.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only; calibration source is marked stale/provisional.*

This is a prospective estimate of the approved correction and remaining acceptance work after plan-quality cleared, not a reconstruction of the initial quick-flow work. One Lua/Neovim feature covers shared entry routing, production-order native regressions and both-runtime verification: v2 design 2.0 × thorough-spec 0.2 = 0.4; implementation 1.5 × v3.1 0.4 = 0.6. One small pure-owner extension uses the smaller-module analogue: design 0.2 × 0.2 = 0.04, implementation 0.5 × 0.4 = 0.2. Docs use 0.1 × 0.2 design and 0.1 × 0.4 implementation. One remaining review uses 0.1 × 0.2 design and 0.5 × 0.4 implementation; disposable conformance/profile acceptance uses real-API discovery 0.4 × 0.4 implementation. Existing owner, Couch seam, fake and native harness are reused; no greenfield library search or new protocol is needed. Familiarity is 1.0 and the thorough plan gets a 15% design buffer. Queue wait is excluded.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.6
item: smaller-go-module design=0.04 impl=0.2
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.2
item: real-api-discovery design=0 impl=0.16
design-buffer: 0.15
total: 1.752
```

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

### 2026-10-22 — R1 REWORK; existing-controller correction proposed

Boundary review returned Critical BR-1 (`admission-handoff-covers-existing-controllers`): production attaches session-sync before S1, while our native helper detached it. Existing-controller adoption returns without acquiring, and its earlier legacy callback can establish tokenless protection; observed saved edits then skip acquisition because that legacy turn reads operator. The review reproduced clean and saved variants on both runtimes, zero producer acquisitions and stale first input. Source inspection confirms this handoff gap. No disposition yet; correction requires native red/green evidence and another boundary review.

Cancelled our obsolete queued suite through `sdlc local-check cancel --run lease-1901041664`; no other runner touched. Proposed plan Revision routes the earlier legacy callback through S1's one input scope, defers tokenless unknown-period writes, and handles adoption into existing controllers with the original baseline/deadline. It explicitly enumerates pre-owned/foreign legacy proof rather than assuming every existing controller is empty. Waiting for TL approval of this mechanism correction before more code. Disposable profile fixture is statically prepared but unrun at `/Volumes/TestScratch/tmp/parley.nvim-slot4/parley-410-profile.H9qNMO/`; no :0 stage or live check held.

### 2026-10-22 — full-flow plan gate; stopped for history re-plan

TL c8405302 approved R1 and required stopping for a re-plan if review found another admission mechanism hole. Invoked change-code with full flow before any further code. Plan-quality raised Important PQ-1 (ordinary release clears history before reacquisition) and PQ-2 (replace test inventories with named function strategies). No code or tests changed after that approval. The durable plan now specifies an owner-controlled legacy_release continuation of acquire: exact release success preserves original baseline/content/history and emits registered acquire immediately; failure retains tokenless proof/history in existing refused phase; post-removal expiry/refusal retains original work. There is no ordinary release/reset or intermediate writable gap. Active tests are described as named function strategies. Waiting for TL review of this re-plan before re-entering the gate. No check/review/editor fixture is running.

### 2026-10-22 — re-plan accepted; production-order correction under verification

TL f0654bf4 approved the owner-acquisition continuation, requested the retire-legacy alternative paragraph, and required stopping if plan-quality found another handoff hole. Added that comparison in plan commit 0f27be94. Full-flow plan-quality rounds 2 and 3 returned CLEAN, disposing PQ-1/PQ-2 with no new findings; estimate-quality INFO and change-code passed at c8e811f1. Its estimate is explicitly prospective correction/acceptance work, so whole-issue actuals cannot be treated as a matching convergence window; the optimistic allowance includes verification execution and prepared-profile acceptance, excludes queue wait.

Production-order native red reproduced unconfirmed first input from a pre-owned legacy turn. Pure-owner sequences red 19/6/0 then green 25/0/0; logs `/Volumes/TestScratch/parley-410-couch-2qky079j/owner-{red,green}.log`. The integrated preferred focus passed 14 native cases plus owner/Couch and affected architecture guards (`/tmp/parley-410-r1-green.log`). Existing controllers now join S1 before tokenless writes, observation anchors unknown-period history in the same owner, and adoption into existing/new controllers uses the exact scope. Internal legacy_release keeps history through exact-byte removal and emits the registered acquire without idle/reset or intermediate gate restoration.

Expanded native verification adds post-removal unavailable/refused retries and standalone typed S1 attachment. The latter red caught using the header-aware is_session_sync predicate where the plan requires an actually attached controller; now checks the existing identity accessor. The timeout fixture writes protection before delaying its reply, so lack of acknowledgment cannot assert absent sidecar; corrected that oracle to exercise same-turn retry. Operator stale-rename diagnosis traced the stall inside nvim_buf_set_name before callback return: typed unknown legacy migration is deliberately refused by the existing #359 preflight. The preflight also refuses unknown prose, so the stale-name test narrowly ignores BufFilePre/Post while changing the name, modeling external name invalidation without exercising migration admission. Migration policy is unchanged. Both-runtime final checks, lint, recorded suite, fresh boundary review and live acceptance remain outstanding. No :0 stage held.

Final-code evidence at 6d34f535: preferred full native 159/0/0; operator focused new native 17/0/0 (including all four pre-owned outcomes and 4/8 counters); owner 25/0/0; prior integrated focus includes Couch 25/0/0 and affected architecture guards. Whole-tree lint 822 files, zero warnings/errors. Disposable real/fake producer conformance and corrupted-fake negative control pass. Full operator native regression is running separately. Recorded suite lease-3241185062, attempt 58772d90cf8ca491fcf530bfd75bc091, is queued normally at position 12 on the pushed code head. Per the permitted overlap, fresh close review may run while it queues; no recorded-suite pass, live acceptance or landing is claimed. Prepared copied-profile fixture now preserves the parent's production legacy-before-S1 order and remains unrun.

### 2026-10-22 — R2 REWORK; stopped for operator policy decision

Fresh boundary review on 8f42416f disposed BR-1 addressed and raised Critical BR-2 in the same `admission-handoff-covers-existing-controllers` family (second instance). Deferring tokenless writes during pending discovery has no background settlement when lookup finishes absent: normal-mode outstanding edits remain unlocked after pending=false/no identity unless another input action happens. Existing regression `tests/integration/session_sync_spec.lua:411` (unresolvable owner, no submission, legacy lock retained) fails at this head and passes with pre-correction c8e811f1 modules. Source inspection confirms the observer defers at session_sync.lua:797–799 and lookup completion at agentic_document.lua:347–355 has no legacy continuation. This is a further mechanism gap, not the separate #412 native refusal timing issue.

Stopped without a product/test patch or another mechanism proposal, per TL c8405302/f0654bf4. Sent the finding and retire-legacy question to the hub; the existing plan paragraph records why retirement changes unknown/absent/unavailable legacy policy and needs an operator decision. BR-1 regressions remain fixed: the reviewer verified 17 native cases on each runtime and owner/Couch 25 each, with substitution red. My complete native runs passed 159/0/0 on EACH runtime; lint and real/fake conformance passed. These do not outweigh the mapped legacy regression. The reviewer's mapped run also stalled and had an overlapping preparation cleanup, so it cannot establish a complete suite pass.

Cancelled obsolete queued suite lease-3241185062 through the supported exact-run command; runner exited context-cancelled and produced no suite result. No suite, review, stage or live profile is running. PR #333 is unlanded; issue remains working. Next action is TL/operator policy direction, not a third patch. Preserve the unrelated generated-workflow stash.

## Revisions

### 2026-10-22 — name crashed-owner recovery before fresh plan-quality

TL aa353a9d agreed RETIRE with the condition that a dead old owner has an existing way out. The existing standalone typed-legacy Alt+Return path supplies it: open without Couch thread scope/tag, then explicitly submit to release exact observed tokenless bytes with a fresh controller. Staleness is only a reminder, not unlock. The plan names this workflow and a permanent restart/native-input regression to add after gate admission, alongside continued inside-S1 refusal and validated v1/v2 recovery. A temporary preferred-runtime probe passes 1/0/0; no product or tracked test code changed. Non-typed orphans with neither live proof nor valid journal have no existing plugin recovery command; this limit is reported to the hub rather than adding a generic unlock.

### 2026-10-22 — operator selects retirement inside S1

TL delivery 8f18c995 reports the operator's RETIRE choice. Extended Spec/Done-when and replaced the active checklist around that chosen policy; prior attempt/results remain in the Log. The durable plan appends an authoritative RETIRE revision, preserving the earlier design as historical text and marking its concept tables historical. No product/test code changed. Proposed compatibility: exact live old proof can finish via explicit Alt+Return; unproven old sidecars require owner-assisted explicit release and remain refused; validated v1/v2 journals use their existing reopen/save/Alt+Return continuation and retire last. New acquisition never deletes/converts old protection, and new moves cannot treat it as fresh admission. Waiting for TL agreement on that rule before fresh change-code/implementation. PR #333 remains unlanded; no suite, review, stage or profile probe is running.

### 2026-10-22 — distinguish implementation checklist from landing evidence

The final Plan checkbox originally combined implemented tests/docs with the recorded suite and live check. Clarified it as completed implementation/verification preparation so SDLC can run its single close review while the suite waits, as tl-worker explicitly permits. The mandatory recorded pass and post-review/suite live acceptance are retained above and in the Log; no requirement is waived or represented as already passed.
