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

- [ ] Build a pure attention_rows forest from already scoped/sorted entries, then render preorder with two leading spaces per level. Preserve sibling order; missing parents become roots and visited-node tracking breaks cycles deterministically without dropping entries.
- [ ] Add one optional pure filter_items hook to float_picker, default behavior unchanged. Attention supplies its pure filter: score every item through the existing scorer, retain matching rows plus ancestors once, return forest order. Query, selection and live-update paths reuse the hook (ARCH-DRY / ARCH-PURE).
- [ ] Red/green nested/orphan/cycle/order tests and counted N/2N traversal/filter tests; real-picker child-search, scope-toggle and late-update regressions; existing architecture guards, dual-runtime focused tests, atlas/README and recorded suite before landing.

No durable state or new actions: existing open/select/type/Ctrl+A continue. A missing/filtered parent displays as a root; malformed cycles display one deterministic root per component; both require no repair and lose nothing. Picker snapshots die on close; store, probes and seen tracking are unchanged. Each layout visits O(N) entries/edges; each search scores N rows once and walks at most N newly retained ancestor edges (plus existing fuzzy-score cost), bounded by the existing 256-entry store. Count parent-field accesses / scorer calls at N and 2N. A disposable real-profile check will be requested from the hub once green.

- [ ]

## Log

### 2026-10-18
