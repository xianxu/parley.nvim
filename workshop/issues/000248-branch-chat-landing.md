---
id: 000248
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.51
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

## Estimate

Produced via brain/data/life/42shots/velocity/estimate-logic-v3.1.md against baseline-v3.1.md, Method A only (calibration marked stale). One focused Lua/Neovim fix: low-end design 1h × 0.2 because the spec resolves landing and ownership; low-end implementation 0.5h × 0.4 ship-time scaling = 0.2h. One boundary review: design 0h, implementation 0.2h × 0.4 = 0.08h. Familiar stack, no novel library needed; 15% design buffer.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.2
item: milestone-review design=0 impl=0.08
design-buffer: 0.15
total: 0.51
```

## Plan

- [x] Replace the source-text landing assertion with behavioral regression tests: drive branch inserters in n/i/v using real temporary chat files; verify opened child, first-question cursor, insertion command, saved anchor, and failed-write refusal.
- [x] Extract shared scheduled child navigation in branch_inserters, using parse_chat first exchange location; call after commit_reference succeeds in each child-creating path.
- [x] Run branch integration tests, full suite and lint; record evidence.
Acceptance boundary: close through SDLC review after the implementation checks above.

## Log

### 2026-09-14

- User specified consistent open-and-edit behavior; scoped fix to existing child creation. Found insert_inline discards commit_reference result and has no navigation; other paths duplicate EOF landing. Existing workspace has unrelated tutorial/bootstrap changes; stage only issue and fix files.

## Revisions

### 2026-09-14 08:54 — Plan review PQ-1/PQ-2

- Name the shared helper `open_branch_question` inside `branch_inserters`. Capture the originating window at the gesture; cancel its scheduled navigation if the window is invalid, no longer current, or no longer displaying the parent. This prevents a deferred gesture stealing focus (ARCH-ORDER).
- Function test strategies in `tests/integration/branch_child_spec.lua`: `open_branch_question` uses adversarial children with trailing template questions and a controlled `vim.schedule` queue to assert parser-directed cursor placement and cancellation after focus/buffer/window changes. Spy only on `startinsert!` while executing other editor commands normally, recording the destination and cursor at insertion request time; restore seams in after_each.
- `insert_plain`, `insert_planned`, and `insert_inline`, reached via `_branch_inserters`: parameterize n/i/v and gathered/plain inputs, compare saved parent references with actual opened child files; force a parent write failure using a BufWriteCmd error and assert no navigation in every mode. Existing foreign-buffer and streaming tests remain acceptance coverage.

### 2026-09-14 — Implementation verification

- Replaced the source-text landing check with 13 behavioral cases. Red run had 8 expected failures: five incorrect/missing landings plus three deferred-focus violations; no test errors. Readonly parent buffers provide real write failures across all five branch variants.
- Shared open_branch_question now handles all child-creating paths after commit_reference succeeds. Targeted ui/keybindings suite passes.
- Separate hermetic headless Neovim smoke entered actual Insert mode on the visual branch's seeded first question and verified typed text appended there; /tmp/parley248-smoke.log. Full make test passed (including lint), exit 0; /tmp/parley248-full.log.

- Close preflight rejected a self-referential unchecked review task. Expressed the acceptance boundary as prose; all implementation tasks are verified.

- Closing review round 1: BR-1 identified stale README visual-branch landing prose. Corrected the user instructions to match all chat creation paths; swept README, docs, atlas, and runtime help for parent-focus/EOF claims. No runtime findings.
