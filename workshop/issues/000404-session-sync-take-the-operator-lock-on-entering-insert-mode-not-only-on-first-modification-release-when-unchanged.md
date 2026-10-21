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

## Done when

- Tests pin: insert takes the lock and paints the band without a change; unchanged escape releases it; changed
  content retains it through auto-save and insert re-entry until submit/full undo; undo while inserting stays
  protected until exit. Existing/foreign locks, disk-write races and plain Markdown remain safe.

## Plan

- [ ] Add red real-headless insert/escape cases for registered parent and side docs, changed auto-save/re-entry, insert undo, late attach and pre-existing/foreign locks; preserve non-insert edit coverage.
- [ ] Share existing first-edit acquisition and deferred race handling with InsertEnter; retain one acquisition baseline; InsertLeave reuses owned baseline release. No watcher/timer (ARCH-DRY).
- [ ] Verify counted hash work at 4/8 mode pairs, focused/native tests, architecture guards and atlas; queue recorded suite and request the live check from the hub.

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
