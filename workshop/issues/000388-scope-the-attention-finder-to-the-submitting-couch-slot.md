---
id: 000388
status: codecomplete
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '24fef0d5cfb71ffaab6e81bbc231c800bea96096' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T12:01:44-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "41d35ac2", done: "41982362"}
actual_hours: 0.21
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

### 2026-10-18 — corrected head green; fresh recorded suite queued

Code/test head 8bd03ed0d49c1f3d2c037d83523134dc0e344487: all 220 focused
cases pass on both preferred 0.12.5 and stock 0.11.7, including the existing
architecture guard; lint clean across 803 files. Close round 2 returned SHIP,
no new findings (same Minor receipt-parser advisory retained). Reviewer also
reran the mapped tests on both runtimes. Fresh recorded full-suite attempt
bee326aaf54d2f6755bd4ab3754cc5ff is healthy and queued on that code head;
log .git/sdlc/test-stats/inflight/bee326aaf54d2f6755bd4ab3754cc5ff/run.log.
Keep its place. Later commits are documentation only, so its result will cover
them. Do not land until this full run passes. No extra stage is needed for the
configuration-key relocation: the default registered key and pane behavior
checked live remain unchanged and are covered by the actual-picker tests.

### 2026-10-18 — first full-suite failure and deterministic fixture diagnosis
- 2026-10-18: closed — Corrected the architecture-guard failure by using attention_finder_mappings.toggle_scope; existing guard unchanged and now mapped into focused tests. All 220 focused cases pass, lint clean in 803 files. Deterministic red/green scorer fixture proves old q+ typo-matched q-prefixed temp tokens; replacement +++ and adversarial qzbeta pin row filtering without changing production matcher or timeout. First recorded run b128ef609d54b16545d71033a29d85f7: 478 PASS files, only mapping-schema guard failed, log retained; no unrelated-flake retry. Fresh recorded suite running on 8bd03ed0. Prior dual-runtime 191-case and disposable real-profile/live-Couch check remain documented; default Ctrl+A behavior unchanged. Hub allows review overlap; fresh recorded dual-runtime full pass is mandatory before landing. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

Attempt b128ef609d54b16545d71033a29d85f7 completed with 478 PASS files and
one failure: single_source_sweeps_spec rejected attention.toggle_scope as a
help_only key outside a _mappings table. No other failure; compatibility was
not reached because make test stopped after that integration phase. Retained
.git/sdlc/test-stats/failed/b128ef609d54b16545d71033a29d85f7.log, sha256
2711aed44af52e5f846373e147de51135a600ef890ddd4cff32c3a1515c2b6cc.
Corrected the config path to attention_finder_mappings.toggle_scope, keeping
the guard unchanged and including it in the targeted map.

The targeted fix run separately timed out the existing typeahead fixture.
Diagnostics led to a deterministic scorer reproduction: q+ matches
"beta.md /tmp/qzfixture" with score 162 because approximate prefix matching
accepts qz. Thus a random temp path token starting q admitted the third row;
it was not slow typeahead. Added a failing scorer fixture, then replaced the
query and matching filenames with punctuation-only +++. It has no word-token
prefix match and no subsequence in an alphanumeric temp path. Pinned positive
and negative scorer cases and an adversarial qzbeta row. No production matcher
or deadline change; no unrelated-flake retry used. Fresh verification follows.

### 2026-10-18 — close review SHIP; recorded suite pending

Close round 1 returned SHIP with no blocking findings. The independent
reviewer reran all 191 focused cases on each installed runtime and confirmed
sender identity, scope/legacy behavior, side-doc inheritance and shared state.
One Minor advisory remains: ID and sender currently parse the same receipt
format independently; consolidate on the next receipt-parser change. Recorded
that prevention rule in lessons. Code is unchanged from queued 3da98e74.
Full recorded suite b128ef609d54b16545d71033a29d85f7 remains a landing gate;
its live runner is healthy and retains its queue place.

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

### 2026-10-18 — honor the existing picker-mapping declaration contract

The first recorded full run found the new help_only action declared under
attention.toggle_scope, which violates the existing _mappings-table guard.
Move only its configuration path to attention_finder_mappings.toggle_scope,
retaining the registered Ctrl+A action and behavior. Add that architecture
spec to the attention targeted map. Do not weaken the guard. This is a small
correction to the approved implementation, not a new state or mechanism;
fresh focused tests, a new recorded suite and re-close review precede landing.
