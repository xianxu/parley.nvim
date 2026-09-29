---
id: 000301
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: '2fbd2ede6c844c2971a01e3e5cc609fa9f2fa761' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T10:58:55-07:00
flow: {kind: quick, provenance: inferred, spec: "8288b012", done: "0b4dc0bb"}
---

# Keep outline tags out of model context

## Problem

Whole-line outline labels are local organization but currently leak into model context.

## Spec

Exclude entire strict whole-line local `@@label@@` and `@@_@@` rows from outgoing chat context, including standalone tags, prior answers and inherited history. Preserve file/URL references, inline/indented/trailing-text lookalikes, fenced examples, tool payloads and local stored/parsed text. Classify original rows before trimming or removing speaker prefixes. ARCH-DRY/ARCH-PURE: question_tags owns the predicate/projection, using existing reference and fence grammar; parser records optional context projections while retaining raw text, and live reads project original rows. Apply the same projection to topic inputs. No new persistence or asynchronous lifecycle.

## Done when

- Attached and standalone whole-line labels (including anonymous labels) are absent from parsed/live/ancestor context; local raw text, spans and outline associations remain.
- File/URL references still load; inline, indented, trailing-text, custom-prefix and fenced examples remain literal, and tool inputs/results are unchanged.
- Empty projected questions, answers and tool-adjacent text are omitted; speaker-line fences work with default/custom prefixes. Captured automatic-topic and ChatPrune requests exclude local labels and preserve literals.
- Regression tests cover original-line classification and all changed context consumers; focused tests and lint pass.


## Plan

- [x] Add failing context regressions, implement shared source-row projection, update docs, verify and close.

## Log

### 2026-09-29

User approved whole-line-only local tags. Follow-up @@ auto-pair typing will be a separate bounded change after this context change. Branch is stacked on #300 to retain the app customization already delivered. Read-only exploration confirmed normalized text cannot preserve original-line semantics, so raw parsed content stays authoritative and context projections are derived.

Context regressions failed before implementation, then passed. Verified chat/format, ui/outline, chat/memory and chat/exchange_model mapped suites plus changed-file Lua lint. Tests cover original-line lookalikes, anonymous/standalone tags, backtick/tilde/nested fenced literals, reference loading, tool input/result byte identity, ancestor context and unchanged local parsed/buffer text.

## Revisions

### 2026-09-29 — review boundary corrections

- BR-1: drop empty projected text blocks/messages, including older questions that otherwise would gain a memory placeholder; preserve tool ordering.
- BR-2: recognize fences in the speaker-line content while classifying tags against original physical rows; cover default/custom prefixes with backtick, tilde and long fences.
- BR-3: capture actual automatic-topic and ChatPrune dispatcher payloads, retaining raw local chat content. Removing the automatic-answer, prune-question or prune-answer projection independently makes these tests fail.

Verification: updated chat/format and chat/memory regressions pass, as do both topic caller specs. BR-1/BR-2 regressions failed before fixes; all three BR-3 mutation probes failed as intended and production files were restored. Changed Lua lint and diff checks pass.

### 2026-09-29 — shared fence rule after second review

Round 2 accepted the empty-content and topic-caller corrections, but BR-2 remained incomplete at turn-boundary preface association and BR-4 found mixed delimiter runs closing fences. ARCH-DRY: association and projection must consume the same row classification. Fence closers must use only the opening character, sufficient width and whitespace-only trailing content; speaker-line openers and turn-boundary termination must agree in both consumers. Extend the regression matrix across these dimensions before re-review.

Verification: the shared scanner passed 23 tag tests, 10 ancestor tests, chat/format (247 tests), ui/outline, Lua lint and diff checks. Before the fix, 12 tag matrix cases and the exact ancestor turn-boundary reproduction failed. Both association and projection now use the same memo, including reference prefaces.
