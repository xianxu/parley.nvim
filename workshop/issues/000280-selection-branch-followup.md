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

## Plan

- [ ] Update seed formatter and selection-only child layout/cursor placement; test content, saved parent and insertion landing.

## Log

### 2026-09-26
