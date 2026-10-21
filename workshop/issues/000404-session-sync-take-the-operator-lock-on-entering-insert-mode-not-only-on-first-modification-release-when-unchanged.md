---
id: 000404
status: working
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: '7b1b81bc5407b63f8b96eb6f2904fcfb230898ce' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-21T01:17:07-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "903492ed", done: "52e7b97d"}
---

# session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged

## Problem

parley takes the operator's session-sync lock on a registered session file or side doc only once the buffer is
modified. Between entering insert mode and the first keystroke that changes text, the TL can still write the file,
so the operator starts typing into a buffer that's about to change under them. Operator, 10-20 (ops side doc
`2026-10-20-22-remote-access.md`): entering insert mode should take the lock, even with no change yet; on the coming
iPhone view, showing the keyboard maps to the same thing.

## Spec

- On InsertEnter in a registered session file or side doc, take the operator lock (as today's first-modification
  path does).
- Release it when: the operator submits (Alt+Return); or they leave insert mode with the buffer unchanged since the
  lock was taken. No idle timer: immediate unchanged exit release covers the intended forgotten-insert case
  (Revision below). Changed content keeps the lock through saves until submit or full undo, as today.
- The lock indicator in the statusline shows it the moment insert mode starts.
- Actual insert departure, including Ctrl-C which skips InsertLeave, ends unchanged intent. Automatic move
  finalization also retains a live insert intent; only explicit submit may release during that intent.

## Done when

- Tests pin: insert takes the lock and paints the band without a change; unchanged escape releases it; changed
  content retains it through auto-save and insert re-entry until submit/full undo; undo while inserting stays
  protected until exit. Ctrl-C/full-undo is covered across parent/side docs, early/late attachment and auto-save
  on/off; moves preserve live intent. Existing/foreign locks, disk-write races and plain Markdown remain safe.

## Plan

- [x] Add red real-headless insert/escape cases for registered parent and side docs, changed auto-save/re-entry, insert undo, late attach and pre-existing/foreign locks; preserve non-insert edit coverage.
- [x] Share existing first-edit acquisition and deferred race handling with InsertEnter; retain one acquisition baseline; InsertLeave reuses owned baseline release. No watcher/timer (ARCH-DRY).
- [x] Verify counted hash work at 4/8 mode pairs, focused/native tests, architecture guards and atlas; queue recorded suite and request the live check from the hub.

- [x] BR-1: one mode-departure handler for ModeChanged/InsertLeave, shared automatic-release eligibility including move finalization, native red/green matrix, renewed verification and suite.

- [x] BR-2: revalidate live intent at persisted cleanup/recovery boundaries; native replay before cleanup, after OLD cleanup and after NEW cleanup, with outside-insert convergence controls on both runtimes.

Landing gates: recorded suite pass, close review, hub's live acceptance, merge and report. Review may overlap a queued suite.

Actions: enter/leave insert, edit/undo, submit; failed release retains the band and existing submit recovery.

| Internal state / failure | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| Free, then insert entry | Operator band immediately | Leave insert unchanged | None |
| Owned insert, baseline restored by undo | Operator band through insert | Leave insert | None |
| Changed content, including auto-save | Operator band | Submit or full undo outside insert | None |
| Unknown/pre-existing or replaced lock | Existing held band | Submit through existing path | No unrelated lock deleted |
| Release fails or foreign write undecided | Existing held band/violation notice | Existing submit reconciliation | No silent overwrite |


## Log


- 2026-10-21: closed — BR-2 negative control: six native retained-journal cases fail before correction, three outside-insert controls pass. Corrected 7e9b74ba: 111 native cases pass on both Neovim 0.12.5 and installed 0.11.7; 71 buffer cases, all architecture/arch-helper/documentation guards and 18 unit cases pass; lint 818 files and diff-check clean. Refusal leaves OLD/NEW witnesses byte-identical at all three cleanup points and leaving insert permits idempotent recovery. Operator live check accepted staged 5c55f1ef (yes, works), verified hub delivery d5c933fc; stage cleared. Fresh suite lease-2323705263 queued on corrected code; landing still requires recorded pass.; review verdict: SHIP
### 2026-10-20

## Revisions

### 2026-10-21 — immediate exit release, no idle fallback

The hub, who authored the Spec, confirmed the 2-minute clause was redundant
(Couch eb3046cd-cedb-4b0b-9d55-7cb278a15945). Immediate unchanged InsertLeave
release is the contract. Do not add timers, watchers or retry loops; a failed
release keeps the existing visible band/notice and recovery. The active Spec
and Done when above replace the timeout wording.

### 2026-10-21 — acquisition design

The existing on_lines callback already acquires before auto-save and schedules
foreign-write reconciliation outside autocmds. Share that effect with insert
entry; never call checktime synchronously inside InsertEnter. Track insert
presence per attachment (discarded on detach), defer baseline release until
exit, preserve pre-existing/foreign ownership and never reset an existing
acquisition baseline on mode re-entry. Late attachment in actual insert mode
gets the same protection. Each mode pair adds a constant number of existing
O(B) content hashes for B buffer bytes; no scan of other buffers, subprocess,
timer or durable format. Count full-buffer reads at 4/8 pairs.

### 2026-10-21 — red tests and input ordering

Before implementation, native tests reproduced five failures (registered
parent/side entry, insert-baseline restoration, late attach, entry disk race);
counted mode-pair tests reproduced two missing-lock failures. Existing non-insert
edit tests passed. Initial shared acquisition passed 83 native / 71 buffer cases.

An added escape/disk-race test then reproduced a deterministic stall: direct
InsertLeave release entered checktime within the input autocmd. The harness
reported idle 50000 ms after nine completed cases. Release now uses the same
deferred reconciliation ordering as edits: clear insert intent immediately,
schedule one guarded baseline check after auto-save/autocmd completion. Rapid
re-entry is protected by the same insert-state guard; detach/move by the
existing attachment/epoch checks. No timer, watcher or retry loop. This is
required by the already planned foreign-write safety contract, not a new scope.

After the 08:44 Couch restart, the design commit and tests survived, both red
runs were complete, and queue/landing status contained no run of this item.
No local-check/merge runner or PR existed; nothing was restarted.

### 2026-10-21 — implementation verified on preferred runtime

All 85 native cases pass after deferring exit reconciliation, including the
new escaped foreign-write case that stalled without deferral. All 71 buffer
cases pass, including counted 4/8 mode pairs (at most four full-buffer reads
per pair). Lint is clean across 818 files and diff-check passes. Native tests
on installed Neovim 0.11.7 and architecture/docs guards follow before the
recorded suite. The README/atlas describe immediate entry and unchanged exit,
continued normal-mode protection, preserved auto-save baseline and no timer.

### 2026-10-21 — targeted verification complete; acceptance pending

All 85 native cases pass on Neovim 0.12.5 and installed 0.11.7. All 71 buffer
cases, architecture/arch-helper/documentation guards and 18 unit cases pass;
lint is clean across 818 files. PR #327 is open, code head f6dfc739. The recorded
suite is started on that pushed head. No pass is claimed until its record
completes. Requested live staging from the hub; the hub has asked the operator
whether to stage or land on tests, and explicitly holds staging meanwhile
(Couch 15033a2b-b627-4fa4-a894-6d2b851b53df). No :0 change was made.

### 2026-10-21 — BR-1: actual mode lifecycle and all automatic releases

Close round 1 returned REWORK: InsertLeave is skipped on Ctrl-C, stranding the
insert flag and preventing unchanged exit/full undo. The hub approved the
correction (Couch 295b743f-027e-4122-8fbd-a00deed06b04): one handler observes
ModeChanged and InsertLeave, ignores insert-family destinations and defers
owned-baseline reconciliation as before. Early entry and late attach use the
same lifecycle. The automatic-release policy must also guard move finalization,
which has its own baseline equality decision; no journal format change.

Native regression matrix covers parent/side × auto-save off/on × early/late
attachment × unchanged Ctrl-C / changed Ctrl-C then full undo. A native move
sequence asserts live unchanged intent stays held through finalization and
releases on actual exit. This generalizes BR-1's family
insert-intent-must-follow-mode (ARCH-PURPOSE). Original suite
lease-4273173816 was cancelled through sdlc local-check cancel by that exact
owned run ID; no unrelated runner was touched and the corrected head requires
fresh recorded verification. Staging remains held pending the operator.

### 2026-10-21 — BR-1 native verification and staging authorization

The new matrix first reproduced 17 failures on the previous implementation
(85 existing cases passed). The corrected shared departure handler and automatic
release predicate pass all 102 native cases on both Neovim 0.12.5 and the
operator's installed 0.11.7. Lint remains clean across 818 files; diff-check passes.
The operator authorized a brief live stage through the hub (Couch
f4dec747-4578-4a3b-8f40-a1902dfb1401), superseding the earlier hold. Stage the
corrected committed head; buffer/architecture guards and the fresh recorded
suite continue while the operator checks Escape and Ctrl-C departures.

### 2026-10-21 — BR-1 guards complete; live stage and suite pending

The corrected 5c55f1ef passes all 71 buffer cases (including counted 4/8 mode
pairs), every architecture/arch-helper/documentation guard and all 18 unit
cases. Both native runtimes passed 102 cases as recorded above. sdlc staged
5c55f1efe87eb5e5f17cd59454ba675e43c259e5 on parley.nvim:0; the hub received the
exact output (submitted receipt 76f99538-63f4-4cf7-b42b-e625414dee8f). Await the
operator's verdict, then clear the stage. PR #327 is updated. Fresh recorded
suite attempt 2b6e01107afb196736b9f9eed53ff068, run lease-2669494922, is queued
on that code head; no pass is claimed. Close review may overlap that queue.

### 2026-10-21 — live acceptance and BR-2 replay boundary

The hub reported the operator's live acceptance of staged 5c55f1ef: "yes, works"
(Couch d5c933fc-e753-40e7-a190-f61cda9662ef, verified submitted). Cleared the stage
through sdlc; parley.nvim:0 is back on clean main. The hub will fast-forward the
operator's checkout after landing.

Close round 2 returned REWORK, disposed BR-1 and raised Critical BR-2 in the
same insert-intent-must-follow-mode family. A persisted release snapshot can
bypass current intent in prepare_move_finalization after restore_move. This is
the second family finding: the earlier sweep missed the destructive replay
boundary. Cancelled only superseded suite lease-2669494922; it was still queued
and recorded no pass. Sent the complete boundary-sweep design to the hub
(receipt 6af94643-691c-4956-83c7-56ae2a3c030f, submitted) before further code:
revalidate current eligibility before automatic lock removal, preserve journal
proofs and interruption recovery, test retained journals before and after each
cleanup effect with live insert and outside-insert convergence controls.

### 2026-10-21 — BR-2 approved release-boundary rule

Hub approval 8a16df6c-691b-4373-a4c7-d95bf786f5ea (verified submitted): every
automatic destructive release revalidates current insert intent; persisted
release permission never overrides fresh intent. Cleanup during insert refuses
with "leave insert mode and reopen <destination> to finish this move". Preserve
the journal format and exact ownership/after-state witnesses. Include recovery
attachment in the pre-effect sweep, so entering insert before restoration cannot
create obsolete protection on OLD while validating an already-cleaned journal.
Enumerated sites: release_if_baseline; move_finalization_snapshot; restored
release admission; prepare_move_finalization protection/retire replay. Legacy
finish_move removes only OLD while NEW remains held; explicit submit remains
the intentional exception. Native tests cover retained journals at all three
cleanup points, entry before and after restore, plus outside-insert replay.
If close raises a third finding in this family, stop and re-plan the entire lock
lifecycle as one state table, as the hub requires. ARCH-PURPOSE/ARCH-DRY.

### 2026-10-21 — BR-2 red/green on preferred runtime

Before production changes the retained-journal matrix reproduced six expected
failures (entry before/after restore at each cleanup point); 105 cases passed,
including the three outside-insert controls. The shared live-intent predicate
now guards automatic release eligibility, recovery admission before attachment,
and the final destructive cleanup boundary. Refusal keeps disk witnesses
unchanged and gives the approved leave-insert-and-reopen action. All 111 native
cases pass on Neovim 0.12.5; lint is clean across 818 files and diff-check passes.
The operator's earlier live acceptance stays recorded above; this replay-only
correction is being verified on both runtimes before renewed suite and review.

### 2026-10-21 — BR-2 targeted verification complete

Code head 7e9b74ba passes all 111 native cases on both Neovim 0.12.5 and installed
0.11.7, including the nine retained-journal cases (three cleanup points × entry
before restore / entry after restore / outside insert). Each refusal checks
byte-identical OLD/NEW protection, then leaving insert permits replay to converge.
All 71 buffer cases, architecture/arch-helper/documentation guards and 18 unit
cases pass; lint 818 files and diff-check are clean. Fresh recorded suite
attempt efa95c06053178e086dd6672142ba1d0, run lease-2323705263, is queued on
7e9b74ba; no recorded pass is claimed. PR #327 is updated; stage remains clear.
