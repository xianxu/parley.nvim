---
id: 000327
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours: 2.424
card_mirror: '1d647dd999b126756fc501c2fa9dd90b33b6c352' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T20:54:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# Alt+o opens the single link in the enclosing entity: a heading's section, or a numbered multi-line bullet

## Problem

The operator (2026-10-14) navigates the TL session file and QA answers with Alt+o. Today Alt+o acts only on the
reference under the cursor, so to follow an answer link (`→ [answer](qa/…)`) at the end of a long, multi-line
Operator-instructions bullet you must first move the cursor onto the link.

## Spec

When Alt+o finds no reference under the cursor, it looks at the enclosing **entity**, using parley's existing entity
notion: on a markdown heading, the section from that heading to the next heading of the same or higher level; on a
numbered item (`N. `), the whole multi-line item up to the next `N. ` line or heading, with the same rule as ops'
`skills-draft/xx-tl/scripts/opinstr.py` (blank lines inside included, trailing ones not). If that entity contains
exactly one link or reference, open it. With several, show a picker (or say how many). With none, keep today's
fallback (`sdlc resolve`, then `gf`). A reference directly under the cursor always wins.

## Done when

- Existing direct Markdown/@@/branch/src references and under-cursor artifact refs retain priority over entity candidates.
- Numbered-item continuation and interior blank rows find the same item, duplicate numbers delimit separate items, trailing blanks lie outside; fenced samples do not contribute boundaries or targets.
- A heading section uses existing same-or-higher heading bounds and chat/header protection; delete/text-object entity behavior stays pinned by regressions.
- Ambiguity shows a picker; cancel, duplicate/late callbacks, edited/deleted sources and switched windows never open a stale choice or trigger fallback.
- Missing-target diagnostics, source-relative resolution and Normal/Insert behavior are preserved; zero candidates keep sdlc resolve then gf. No new URL/fragment policy (#323).
- README and atlas explain the interaction, mapped tests/full suite/close review pass, and the TL's required live-editor acceptance is recorded before merge.

- On an Operator-instructions bullet whose last line ends in `→ [answer](qa/…)`, Alt+o anywhere in the bullet opens
  the answer (test); on a heading with one link in its section, Alt+o opens it (test); several links → picker;
  cursor-on-link unchanged (regression test).

## Core concepts

| Concept | Kind | Location | Status |
|---|---|---|---|
| Navigation entity | PURE | lua/parley/entity_range.lua navigation_range | New entry; existing text-object/delete behavior retained |
| Reference occurrences and picker completion | PURE | lua/parley/reference_candidates.lua | New canonical enumeration and pending/settled transition |
| Cursor parser consumers | PURE | lua/parley/issues.lua and lua/parley/init.lua | Derive from canonical scanner; preserve old behavior |
| Alt+o boundary | INTEGRATION | lua/parley/init.lua OpenFileUnderCursor | Extend after direct reference; reuse open/resolve/picker seams |

## Plan

Durable plan: [Enclosing-Entity Link Navigation](../plans/000327-entity-link-navigation-plan.md).

- [ ] Add pure navigation ranges and shared occurrence parsing with regression coverage for existing consumers.
- [ ] Integrate sole-target opening and ambiguity picker; cover direct priority, cancellation/stale callback, source-relative paths, mode and zero-result fallback.
- [ ] Update README/atlas/traceability, run targeted and full checks, close review, obtain required live acceptance through the hub, and land on SHIP.

## Log

### 2026-10-14
- 2026-10-14: unclaimed: Parked by operator priority for #330; design committed, no implementation. Resume after #330; plan approval remains unconfirmed due uncertain Couch delivery.

- Claimed #327 after #324 landed and its :0 stage cleared. start-plan refreshed the private Ariadne substrate, required a rerun, then created this main-based issue branch.
- Read the issue, existing entity_range/Markdown/cursor/reference code and ops opinstr.py. The latter uses column-zero numbered anchors, includes interior blanks, trims trailing blanks, and allows repeated numbers. Its fixed Operator-instructions section ends at a level-2 heading; #327's general numbered range follows the issue's explicit next-heading boundary.
- Recommended a navigation-only entity entry over changing all existing text-object/delete semantics. Shared occurrence enumeration avoids duplicated Markdown/@@/branch parsers and reuses artifact_ref's loose shape detector; opening stays in existing trusted seams.
- Full-flow plan written via superpowers-writing-plans because expected source additions exceed the 100-line quick shell. One atomic close boundary, no artificial Mx. Estimate remains unset until plan-quality admission. No implementation code edited. Plan sent to the hub for product-steward review.

- Plan handoff to hub used /tmp/parley327-plan-to-hub.md. Couch send b905c670-70d5-427e-9069-1dc581808f12 returned an uncertain timeout; receipt query said unavailable. Hub peek showed no confirmation. Do not treat delivery or design approval as established; no implementation/change-code yet. Earlier #324 landing report 52efaa47-22d0-48ce-a681-c1116592ebbd had the same uncertain/unavailable result; the proposed #327 handoff also records #324's verified landing and cleared stage. Follow Couch recovery, without blindly retrying unknown delivery.

- Resumed #327 after #330 and #331 landed. Reclaimed its released branch, merged current main at integration 47aff671002a51456938f78004d386235b1a64cb, and reran start-plan. No implementation/change-code yet. The previous design approval remains unconfirmed; a new product-review handoff is being sent for this resumed work. Updated delivery instructions to worker-owned staging and mandatory live acceptance.

- TL approved the resumed full-flow design (Couch delivery 9c9ad248-287c-4ac9-9340-c8b4527dc3c0): navigation-only numbered ranges, shared scanner, direct-reference priority, guarded ambiguity picker, and existing zero-candidate fallback. Build, full suite and close review are authorized, followed by staging on parley.nvim:0. Hold landing for the operator's morning live check; :0 is on main at 41899819. Next: change-code plan-quality admission, then estimate and implementation. No implementation has started.

## Estimate

Produced via brain/data/life/42shots/velocity/estimate-logic-v3.1.md against baseline-v3.1.md. Method A only; calibration source is marked stale, so figures remain provisional.

Two focused Lua/Neovim concerns cover pure navigation/scanning and editor/picker integration; shared-parser refactoring, documentation and one close review are separate primitives. Existing entity/fence/opening libraries cover the work without new dependencies. Thorough approved APIs apply design ×0.2, familiar stack ×1.0, implementation ×0.4 per v3.1, and design buffer +15%. Chosen raw design/impl hours: Lua 2/1 and 2/1.5; refactor 0.6/0.35; docs 0.1/0.1; review 0.1/0.35.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.4
item: lua-neovim design=0.4 impl=0.6
item: cross-cutting-refactor design=0.12 impl=0.14
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.14
design-buffer: 0.15
total: 2.424
```

## Revisions


- 2026-10-14 — initial design clarifies navigation-only range ownership, direct artifact priority, fenced-code exclusion, occurrence counting and stale-picker cancellation; existing URL/fragment destination policy is retained rather than broadening #327 into #323.

- 2026-10-14 — resumption incorporates landed session-sync fixes; correct staging ownership/acceptance sequencing in the durable plan. No navigation scope change.
