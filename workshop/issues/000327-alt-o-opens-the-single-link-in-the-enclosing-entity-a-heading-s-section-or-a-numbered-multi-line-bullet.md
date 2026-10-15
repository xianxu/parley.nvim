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
| Selected artifact opening | INTEGRATION | lua/parley/artifact_ref.lua goto_ref_at_cursor | Optional origin guard through scheduled results and family selection |
| Alt+o boundary | INTEGRATION | lua/parley/init.lua OpenFileUnderCursor | Extend after direct reference; reuse open/resolve/picker seams |

## Plan

Durable plan: [Enclosing-Entity Link Navigation](../plans/000327-entity-link-navigation-plan.md).

- [x] Add pure navigation ranges and shared occurrence parsing with regression coverage for existing consumers.
- [x] Integrate sole-target opening and ambiguity picker; cover direct priority, cancellation/stale callback, source-relative paths, mode and zero-result fallback.
- [x] Update README/atlas/traceability and pass targeted/full checks for close review and staged delivery.

## Delivery

- [ ] Close review on SHIP, then stage on parley.nvim:0 and report exact commit and pickup steps to the hub.
- [ ] Obtain operator live acceptance through the hub before landing, then clear the stage and report the verified merge.

## Log


- 2026-10-15: closed — BR-1 corrected and required full suite passed on 1e028d015f254691cc8ada4d79cec58a5d263475:431 specs, lint728 clean, process census clean, log sha256 prefix4d4885404188. BR-2 now has an opt-in offline real/fake conformance check: all six cases pass through production run_resolve/parse/dispatch; deliberate wrong-kind mutation fails. make -k check-sdlc-conformance passes. No production Lua changes since green suite; full declared suite also rerunning on d09dfa7998a94abd21bc242b56c08a068966289d. PR239; stage only after final suite and SHIP; operator live acceptance mandatory before merge.; review verdict: SHIP
### 2026-10-14
- 2026-10-14: unclaimed: Parked by operator priority for #330; design committed, no implementation. Resume after #330; plan approval remains unconfirmed due uncertain Couch delivery.

- Claimed #327 after #324 landed and its :0 stage cleared. start-plan refreshed the private Ariadne substrate, required a rerun, then created this main-based issue branch.
- Read the issue, existing entity_range/Markdown/cursor/reference code and ops opinstr.py. The latter uses column-zero numbered anchors, includes interior blanks, trims trailing blanks, and allows repeated numbers. Its fixed Operator-instructions section ends at a level-2 heading; #327's general numbered range follows the issue's explicit next-heading boundary.
- Recommended a navigation-only entity entry over changing all existing text-object/delete semantics. Shared occurrence enumeration avoids duplicated Markdown/@@/branch parsers and reuses artifact_ref's loose shape detector; opening stays in existing trusted seams.
- Full-flow plan written via superpowers-writing-plans because expected source additions exceed the 100-line quick shell. One atomic close boundary, no artificial Mx. Estimate remains unset until plan-quality admission. No implementation code edited. Plan sent to the hub for product-steward review.

- Plan handoff to hub used /tmp/parley327-plan-to-hub.md. Couch send b905c670-70d5-427e-9069-1dc581808f12 returned an uncertain timeout; receipt query said unavailable. Hub peek showed no confirmation. Do not treat delivery or design approval as established; no implementation/change-code yet. Earlier #324 landing report 52efaa47-22d0-48ce-a681-c1116592ebbd had the same uncertain/unavailable result; the proposed #327 handoff also records #324's verified landing and cleared stage. Follow Couch recovery, without blindly retrying unknown delivery.

- Resumed #327 after #330 and #331 landed. Reclaimed its released branch, merged current main at integration 47aff671002a51456938f78004d386235b1a64cb, and reran start-plan. No implementation/change-code yet. The previous design approval remains unconfirmed; a new product-review handoff is being sent for this resumed work. Updated delivery instructions to worker-owned staging and mandatory live acceptance.

- TL approved the resumed full-flow design (Couch delivery 9c9ad248-287c-4ac9-9340-c8b4527dc3c0): navigation-only numbered ranges, shared scanner, direct-reference priority, guarded ambiguity picker, and existing zero-candidate fallback. Build, full suite and close review are authorized, followed by staging on parley.nvim:0. Hold landing for the operator's morning live check; :0 is on main at 41899819. Next: change-code plan-quality admission, then estimate and implementation. No implementation has started.

- 2026-10-15: plan-quality found selected-occurrence identity and asynchronous final-effect validation gaps plus test-strategy prose. Verified against the legacy nearest/leading @@ parser and unguarded resolver, refined the design, and cleared all three findings. Full change-code admitted; estimate-quality INFO asks allocation clarity: the first Lua primitive owns new pure logic; refactor owns wrapper migration/regressions; the second Lua primitive includes delayed resolver/family effects and native editor smoke; review/docs allocations include active suite/stage/landing work, excluding idle operator waiting.
- Implemented navigation-only numbered ranges with shared fence/header/exchange context, shared occurrence parsers and exact selected-kind dispatch; existing edit ranges remain unchanged. Added one-shot picker and resolver completion guards through secondary family selection. A nested @@ label inside unsupported Markdown also must not be reinterpreted; a red regression led to dispatching Markdown only through Markdown/src/inline-branch handlers.
- Targeted navigation map: 329 cases across 13 specs pass, including six real child-Neovim Alt+o Normal/Insert/cancel checks and six real filesystem-backed sdlc resolver cases. Pure stage: 99 cases (55 range, 13 scanner/transition, 31 artifact) pass. Lua lint and diff checks pass. Initial expected-red runs recorded missing feature/guard effects. A prematurely overlapped harness run reaped the first parity sweep; the isolated rerun then reached a separate 67-second deadline, with all other mapped editing tests green. Baseline timing is being checked in a separate temporary checkout; no deadline/configuration is changed. Full suite and close review remain pending.

- Isolated parity comparison passed all 11 cases on both untouched main 41899819358e94ad39ffaaa0f4cb94963792708c and implementation a332b9f39d51c7108b5867b5e502ef16acd95874, with unchanged specs/deadlines. Baseline wall/user CPU 34.38s/14.10s; branch 44.30s/14.42s. Machine load rose to roughly 102 on 12 CPUs, supporting scheduling pressure as the timeout cause; no assertion regression reproduced. Separate fake issue-creation compatibility map passed all 4 routes. PR239 opened; full suite queued through the mandatory machine gate.

- Final failure-path audit found native gf errors skipped temporary cursor restoration for a selected non-Markdown target. A red test observed row2/col13 instead of original row1/col3; protected fallback execution now restores before propagating the same E447. All 49 open-reference tests plus six native cases pass. Canceled the obsolete queued suite (our own cwd-verified sdlc process, SIGINT exit130) before it executed; the corrected pushed head must receive the required full run.

- Full suite on a8e7e972f552b07faa656300cb3b1eb0e1c03d3c completed in 2m14s after the long FIFO wait: lint728 files clean, 430 spec files passed and only tests/arch/single_resolver_spec.lua failed. Its broad path-reader heuristic treated pure candidate enumeration as a resolver consumer. Added the explicit pure-parser exemption with the existing annotation exemption, naming init.lua as the resolution owner; mapped the guard alongside navigation. All 17 focused architecture/scanner cases then passed. Full suite rerun is required on the updated test/mapping head; no remaining test phase was skipped.

- Final required suite passed on 20e35d1adf71d1e4b67ca964267c49e4faff776b: all 431 spec files, lint728 files with zero warnings/errors, clean process census; runtime2m7s, log sha256 prefix3491086c673f. The full retry includes the fixed architecture guard, real native input, real fake-process resolution, deletion parity and packaging checks. PR239 server checks are green. Close review is next; operator live acceptance remains pending and mandatory before merge.

- Close round1 returned REWORK for BR-1 (navigation-entity-boundaries): reusing paragraph structural walls excluded branch-reference continuations. Fixed the rule across all eight default/configured prefix families, retaining only real transcript turns as extra item boundaries. The same sweep added plain-Markdown fence coverage and a shared context-specific mask. Red tests observed all affected command/range cases; green navigation map360 cases14 specs, lexical/highlight30 cases and editing parity group109 cases. Lint/diff checks clean. Full suite and boundary review will rerun on the corrected code; live acceptance remains pending.

- BR-1 correction verified by the required full suite on 1e028d015f254691cc8ada4d79cec58a5d263475: all 431 spec files pass, lint728 files clean, no surviving test processes; runtime2m1s, log sha256 prefix4d4885404188. This run includes the complete prefix/fence class and unchanged editing behavior. Rerunning close review before staging; operator live acceptance remains pending.

- Close round2 verified BR-1 by reverting the range correction and observing 22 range/four command failures, then passed all473 mapped tests at head. BR-2 requires live resolver conformance. Added an offline temporary-repository check covering six real/fake cases through production run_resolve/parse/dispatch: sole issue, family, milestone, external empty, missing issue and missing milestone. make -k check-sdlc-conformance passes; an alternate fake returning wrong-kind fails the consumed projection assertion (negative log /tmp/parley327-conformance-negative.log). Tooling documents execution after runner/fake changes and before close. Plugin behavior is unchanged; final suite and close review rerun before staging.

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

- 2026-10-15 — separate implementation verification from post-close live delivery checkboxes so a close does not falsely claim operator acceptance or landing. Done-when still requires live acceptance before merge.

- 2026-10-15 — BR-1: narrow numbered-item boundaries to next numbered anchor/heading plus actual transcript user/assistant turns; annotation prefixes remain content. The full prefix sweep also corrects plain-Markdown fenced samples through an optional shared memo policy, preserving existing transcript/editing defaults. Required full suite and review must rerun on this correction.

- 2026-10-15 — BR-2 external-dependency-conformance: extend the opt-in maintainer check beyond help discovery to real versus fake resolve argv and consumed files/path/kind/milestone responses, plus missing-reference failure. Use temporary Git repositories and committed vocabulary with no real tracker writes or network. Run after runner/fake changes and before closing such work (ARCH-MOCK). Product behavior and live acceptance sequencing stay unchanged.
