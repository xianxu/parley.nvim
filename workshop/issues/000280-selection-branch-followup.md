---
id: 000280
status: working
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
started: 2026-09-26T00:04:13-07:00
flow: {kind: quick, provenance: inferred, spec: "58bd1b89", done: "537e7912"}
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

- Red: selection child wording and insertion landing differed from requested draft.
- Green: 18 branch-submit unit cases and 63 branch-child integration cases pass; exact layout/cursor, custom prefix, percent signs, parent durability and unchanged plain/gathered modes covered.
- Changed Lua lint and scoped whitespace checks pass. Operator tutorial edits remain excluded.

## Revisions

- 2026-09-26: Full boundary review includes earlier stacked app changes. Correct the launch/reset race and assemble app aliases inside the existing registry loop; Option+i scope remains unchanged.

- Architecture guard follow-up: record the modified child-creation API and cursor helper in Core concepts; no new implementation scope.

- BR-1 corrected with sibling operation lock and deterministic competing-launch/reset regressions (8 launcher tests pass). BR-2 corrected by assembling all aliases in the registry loop; architecture suite 25 pass and starter option tests 7 pass.
