---
id: 000390
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '19b715f9c12433f3a0b6f85c7cb7b5007bc072d2' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T15:22:33-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "622aeba9", done: "4211061d"}
---

# Show side-document trees in the attention finder

## Problem

The attention finder presents side docs as a flat list, obscuring which request each response belongs to.

## Spec

Group side docs beneath their listed parent, recursively, with two spaces indentation per level. Keep top-level entries newest-submit-first; a missing/filtered parent makes a side doc top-level. Keep current-slot scope and Ctrl+A unchanged. Search must find children and show their parent above each match (including ancestor context for nested matches).

## Done when

- Parent/child/grandchild rows render in tree order with two spaces per level, preserving existing top-level ordering.
- Missing or slot-filtered parents leave their children at top level; malformed parent cycles terminate without losing or duplicating entries.
- Searching a child retains its ancestor context in tree order; unrelated branches are excluded.
- Scope toggling, selection, query retention and late refresh keep their existing behavior; tests cover the real picker.

## Plan

- [x] Build a pure attention_rows forest from already scoped/sorted entries, then render preorder with two leading spaces per level. Preserve sibling order; missing parents become roots and visited-node tracking breaks cycles deterministically without dropping entries.
- [x] Add one optional pure filter_items hook to float_picker, default behavior unchanged. Attention supplies its pure filter: score every item through the existing scorer, retain matching rows plus ancestors once, return forest order. Query, selection and live-update paths reuse the hook (ARCH-DRY / ARCH-PURE).
- [x] Red/green nested/orphan/cycle/order tests and counted N/2N traversal/filter tests; real-picker child-search, scope-toggle and late-update regressions; existing architecture guards, dual-runtime focused tests, atlas/README; schedule the recorded suite for the landing gate.

Indentation emission also costs O(B) output bytes (B <= 65,280 spaces for a maximal 256-node chain); the counted bound concerns node/edge traversal, not the required output.

No durable state or new actions: existing open/select/type/Ctrl+A continue. A missing/filtered parent displays as a root; malformed cycles display one deterministic root per component; both require no repair and lose nothing. Picker snapshots die on close; store, probes and seen tracking are unchanged. Each layout visits O(N) entries/edges; each search scores N rows once and walks at most N newly retained ancestor edges (plus existing fuzzy-score cost), bounded by the existing 256-entry store. Count parent-field accesses / scorer calls at N and 2N. A disposable real-profile check will be requested from the hub once green.


## Log

### 2026-10-18 — implementation and red/green

Added tests failed the original flat implementation for grouping, nesting,
cycles, ancestor search and counted traversal. Pure rows now build a forest
from already scoped entries and retain matched ancestors in tree order.
The shared picker has one optional pure filter_items callback, using its
existing scorer; no attention-specific logic entered the picker. The actual
picker integration exposed its default bottom anchor reversing visual order:
attention now uses the existing top anchor so parents appear above children.
Existing side-doc assertions were updated to parent-first order while retaining
all seen/retirement behavior checks. Added real child selection across scope
and late repaint, plus scoped orphan promotion/reattachment. No store migration,
new action, watcher or probe lifecycle. Prior #388 punctuation-only search
fixture is retained to avoid random temp-path typo matches.

### 2026-10-18

## Revisions

### 2026-10-18 — review while suite queues

The focused and disposable live checks are complete. The recorded suite remains
a mandatory landing gate; schedule it before close so the review can overlap
the machine queue rather than making queue completion a plan checkbox.

### 2026-10-18 — verification and disposable stage

317 focused cases passed on each of Neovim 0.12.5 and stock 0.11.7; lint passed
805 files with zero warnings/errors. Recorded suite c089ff0b4d6e13aee06d0413bf4e1d11
is queued on f13e2f12. The hub-approved disposable real-profile check used stock
0.11.7, /Users/xianxu/.config/nvim/init.lua and the staged plugin on :0, with a
temporary state directory and five fixture files only. It passed root ordering,
two/four-space nesting, scoped orphan promotion and all-slot reattachment,
ancestor search and Ctrl+A query retention. The first check script counted
blank picker padding as results; counting nonblank rows fixed the assertion,
with no product change. Evidence: /tmp/parley-390-live-result.json and
/tmp/parley-390-live.log. Scratch files/state were removed and the stage cleared.
Attention now visibly opens anchored at the top, so parents appear above their
children. The hub requested this visible change in the landing report.

### 2026-10-18 — BR-1 cycle descendants

Review reproduced a descendant arriving before its cyclic ancestors: promoting
each unvisited entry detached it from its listed parent. Resolve the remaining
component to a cycle member, then traverse children, breaking only one cycle
edge. Cover self-cycle children, multi-node cycle children and nested descendant
chains with parentage, ancestor search, uniqueness and N/2N traversal bounds.
The original queued suite was cancelled unchanged before execution; run a fresh
recorded suite on the correction. ARCH-PURPOSE: preserve every non-cycle edge.

BR-1 verification: all four new regression cases failed the reviewed code;
after cycle-member promotion all 321 focused cases pass on each of 0.12.5 and
0.11.7. Lint remains clean across 805 files. No IO, state, picker or live-profile
behavior changed in the correction.
