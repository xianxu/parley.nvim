---
id: 000248
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours:
started: 2026-09-14T08:51:22-07:00
---

# Open inserted branch chat consistently

## Problem

Alt+i creates an anchored child from a visual selection but leaves focus in the parent. Normal/insert branches navigate to EOF, which can be a trailing empty question rather than the seeded first question.

## Spec

For a Parley chat, all branch creation paths (plain n/i, gathered n/i, visual selection) open the new child after saving its parent reference and place the cursor at the end of the first question header line in Insert mode. Keep the selected text as the inline anchor and the existing seeded question. Use a shared scheduled navigation helper and the chat parser to locate the first question (ARCH-DRY). Preserve foreign-markdown ownership rules, streaming refusals, and stay in the parent if saving fails (ARCH-ORDER). No model submission occurs.

This is a small UI glue fix: existing parser supplies the question location (ARCH-PURE); no new external service, credentials, durable file family, or background worker. One scheduled navigation and one parse of a newly created child per gesture (ARCH-CONSTRAINTS). Paths remain fnameescape-escaped (ARCH-SECURE); existing chat lifecycle owns persistence (ARCH-FUNERAL).

## Done when

- Visual selection opens its child on the seeded first question in Insert mode.
- Plain and gathered n/i branches use the same landing, even with a trailing template question.
- Parent anchor is saved before navigation; save failure and foreign markdown stay put.

## Plan

- [ ] Replace the source-text landing assertion with behavioral regression tests: drive branch inserters in n/i/v using real temporary chat files; verify opened child, first-question cursor, insertion command, saved anchor, and failed-write refusal.
- [ ] Extract shared scheduled child navigation in branch_inserters, using parse_chat first exchange location; call after commit_reference succeeds in each child-creating path.
- [ ] Run branch integration tests, full suite and lint; record evidence and close through SDLC review.

## Log

### 2026-09-14

- User specified consistent open-and-edit behavior; scoped fix to existing child creation. Found insert_inline discards commit_reference result and has no navigation; other paths duplicate EOF landing. Existing workspace has unrelated tutorial/bootstrap changes; stage only issue and fix files.
