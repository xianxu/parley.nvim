---
id: 000388
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '05a61ba94b627bda4ba6682a95597c8208e6d183' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T12:01:44-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "41d35ac2", done: "41982362"}
---

# Scope the attention finder to the submitting Couch slot

## Problem

Every editor shares attention.json, so a Couch pane currently lists submits made from other slots.

## Spec

Record the submitting pane's Couch slot on each attention entry. Default the finder to the current slot, with one key toggling all slots. Keep one store file and shared seen/side-doc tracking. Legacy entries without a slot remain visible everywhere; outside Couch show all. Operator design: ops/teams/devinfra/qa/xian-xu/2026-10-18-11-attention-per-slot.md.

## Done when

- Successful submits carry the originating pane slot, including when routed to a different owner.
- Current-slot view excludes other slots, includes legacy entries, and toggles to all and back without losing updates.
- Outside Couch shows all; side docs inherit their parent's submitting slot.
- Store round-trip and submission/finder regressions pass; shared tracking remains intact.

## Plan

- [x] Extend the existing submitted/discovered transitions and typed store with optional slot. Use the accepted receipt's sender, never its recipient; the latest submit owns the existing per-file entry, like its breadcrumb. New side entries inherit their current parent's slot.
- [x] Resolve this pane through couch.own_slot on open; filter in the pure model, repaint from the latest store snapshot, and add a registered Ctrl+A toggle with a scope label. Outside Couch shows all; failed in-Couch resolution shows all with an explicit warning.
- [x] Red/green model, store, both submit paths and picker toggle/late-refresh tests; atlas update, record the hub-authorized real-profile check, and schedule the mandatory full suite.

Actions: submit, open finder, toggle scope, reopen. Existing waiting/answered/seen states and global seen/saved tracking remain unchanged (ARCH-DRY, ARCH-PURE). Filtering is one O(N) pass per repaint, N <= 256; counted N/2N regression pins it. Slot adds one bounded scalar per existing entry, removed by the existing sweep/eviction.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| Bound pane, current/all toggle | Scope in title; matching rows or all | Toggle scope | None; latest submit replaces per-file slot |
| Outside Couch or legacy entry | All entries / legacy visible in either scope | Open finder | None |
| Pane identity unavailable | All slots, warned | Reopen | Filtering unavailable; no entries lost |
| Store/probe failure | Existing warning / unknown row | Reopen | Existing store-write failure may lose a record; unchanged |

- [ ]

## Log

### 2026-10-18 — focused verification and disposable live check
- 2026-10-18: closed — 191 focused cases pass on preferred Neovim 0.12.5 and stock 0.11.7; lint 0 warnings/errors in 803 files. Red/green covers sender instead of recipient, latest resubmit, inherited side-doc slot, typed store/legacy, O(N) membership counts at 16/32, current/all toggle and late probes, real picker query retention, remapping/disable. Hub-authorized disposable real-profile/live-Couch check on staged :0 passed current+legacy 2/all 3/back 2/outside 3; scratch removed, stage cleared and :0 clean exactly at origin/main. Atlas and README updated. Recorded full suite b128ef609d54b16545d71033a29d85f7 is queued on code-identical 3da98e74; hub explicitly allows review overlap, and a recorded pass remains mandatory before landing. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

All 191 focused cases passed on both preferred 0.12.5 and stock 0.11.7;
make lint reports 0 warnings / 0 errors across 803 files. Full recorded suite
b128ef609d54b16545d71033a29d85f7 is queued on pushed code head
3da98e74b8ef7c41dfbbd7b1847c8e73f128da6b; preserve its queue place.
PR #309: https://github.com/xianxu/parley.nvim/pull/309.

Hub-authorized stage of that head on parley.nvim:0, then a new headless
operator-profile Neovim 0.11.7 (/Users/xianxu/.config/nvim/init.lua), loading
attention.lua from /Users/xianxu/workspace/parley.nvim. A pre-init config set
state_dir/log_file to disposable scratch; no live attention store or real
document was used. Real couch.own_slot resolved parley.nvim:1. Fixture rows:
current+legacy 2, actual Ctrl+A all 3, back 2, outside Couch 3. All passed.
Initial check assertions compared /var with its canonical /private spelling;
correcting the scratch assertion (no production change) admitted the check.
No submits or registry writes were made. Removed all scratch fixture files
and their temporary store; evidence /tmp/parley-388-live-result.json and
/tmp/parley-388-live.log. Cleared the stage, then fast-forwarded :0's main
(the clear restored its prior main) to origin/main as the hub requested;
exact Git equality is recorded in the report. Full-suite result is pending;
close review may overlap the queue, but landing requires a recorded pass.

### 2026-10-18 — implementation and red/green evidence

The original implementation failed the new current-slot picker, scope-filter,
submit-origin, store round-trip and counted membership tests. Added an optional
slot to the existing model/store, taking it from the accepted receipt's sender.
The existing per-file identity remains: latest submit sets its slot/breadcrumb;
older pending IDs remain. New discovered side docs inherit the parent's slot.
No store split, new watcher or probe lifecycle was added. The model membership
pass reads each entry's slot exactly once at 16 and 32 entries before sorting.
The picker uses the existing own_slot/query seam, registered configurable
Ctrl+A, latest state on repaint and explicit current/all title. Its failed
resolution fallback is all slots with a reopen warning. Real-picker fake-Couch
coverage exercises pane lookup, the installed key and retained typed query.
Nested keybinding configuration uses the registry's existing shortcut-table
contract; remapping/disable coverage exposed and corrected the initial string
fixture. No architectural scope change.

### 2026-10-18

## Revisions

### 2026-10-18 — separate implementation completion from landing validation

The hub authorized close review to overlap the queued full suite. Correct the
last Plan checkbox, which accidentally included close and landing themselves:
it now records implemented tests/docs, completed real-profile evidence and the
scheduled suite. The full recorded pass, close verdict and actual landing stay
mandatory workflow gates; a checked implementation row does not claim those
pending results. No scope or behavior change, and no gate exemption requested.
