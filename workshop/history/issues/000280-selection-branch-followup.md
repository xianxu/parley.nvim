---
id: 000280
status: done
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
started: 2026-09-26T00:04:13-07:00
flow: {kind: full, provenance: inferred}
actual_hours: N/A
---

# Seed selection branches with a quoted follow-up question

## Problem

Option+i on a selection should prepare a follow-up draft instead of asking for a definition.

## Spec

Seed selection branches with `💬: follow up question`, then `> selected-text`,
a blank separator and an empty typing line. Open that line in Insert mode.
Reuse the shared seed formatter for lazy-created inline links (ARCH-DRY); preserve
plain branches, gathered quote prompts, parent anchors and existing single-line selection scope.

## Done when

- Selection branches contain the requested quoted draft and cursor lands on the empty line below it.
- Normal branches/gathered quotes retain their format; selections preserve quotes, percent signs and custom user prefix.

- Stacked app review corrections serialize competing launch/reset and preserve the shortcut architecture guard.

## Plan

- [x] Update seed formatter and selection-only child layout/cursor placement; test content, saved parent and insertion landing.

## Core concepts

| Entity | Kind | Location | Status |
|---|---|---|---|
| `seed_question` | PURE | lua/parley/branch_submit.lua | modified |
| `create_child_chat` | INTEGRATION | lua/parley/init.lua | modified |
| `open_branch_question` | INTEGRATION | lua/parley/init.lua | modified |

## Log

### 2026-09-26
- 2026-09-26: closed — Selection behavior: 18 formatter and 63 branch-child cases pass. BR-1: 8 launcher tests pass, including deterministic competing launch/reset in both orders. BR-2: all 25 architecture cases, 7 starter option cases and 18 starter integration cases pass. Lua/shell lint and scoped whitespace pass. Operator tutorials preserved. Actual telemetry unavailable; N/A avoids fabricated hours.; review verdict: SHIP
- 2026-09-26: flow upgraded quick → full — 123 added lines in code files (limit 100); an earlier round of this close already ran the full review

- Red: selection child wording and insertion landing differed from requested draft.
- Green: 18 branch-submit unit cases and 63 branch-child integration cases pass; exact layout/cursor, custom prefix, percent signs, parent durability and unchanged plain/gathered modes covered.
- Changed Lua lint and scoped whitespace checks pass. Operator tutorial edits remain excluded.

## Revisions

- 2026-09-26: Full boundary review includes earlier stacked app changes. Correct the launch/reset race and assemble app aliases inside the existing registry loop; Option+i scope remains unchanged.

- Architecture guard follow-up: record the modified child-creation API and cursor helper in Core concepts; no new implementation scope.

- BR-1 corrected with sibling operation lock and deterministic competing-launch/reset regressions (8 launcher tests pass). BR-2 corrected by assembling all aliases in the registry loop; architecture suite 25 pass and starter option tests 7 pass.

## Manual shipment — 2026-09-26

Closed and archived at the operator’s explicit direction as part of the completed local stack. Prior SDLC review records remain historical; no new gate verdict is claimed.

Existing codecomplete review and acceptance evidence are retained; this shipment publishes the completed implementation.

Final verification: lint passed all 656 Lua files; `make test` passed 391 spec files, with the remaining performance spec passing all three cases on a standalone normal-harness rerun. Both runs ended with no surviving test processes. Startup also passed 183 cases in a tracked isolated checkout.
