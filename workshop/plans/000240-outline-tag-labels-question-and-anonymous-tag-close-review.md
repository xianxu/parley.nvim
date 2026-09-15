# Boundary Review — parley.nvim#240 (whole-issue close)

| field | value |
|-------|-------|
| issue | 240 — Outline tag conventions: an @@tag@@ immediately before a question labels it; @@_@@ is anonymous and hides itself, or the question it precedes |
| repo | parley.nvim |
| issue file | workshop/issues/000240-outline-tag-labels-question-and-anonymous-tag.md |
| boundary | whole-issue close |
| milestone | — |
| window | 25197533d70f3399947d0f789bc8e217c6abfd2d..49a1a2a1946b0ab43fca0da09522d856322e03e7 |
| command | sdlc close --issue 240 |
| reviewer | codex |
| timestamp | 2026-09-14T20:42:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Preface parsing, outline projection, context composition, and regeneration are well covered and passed focused verification. Shipping is blocked by exchange-editing consumers that still assign prefaces to the wrong exchange, a Core concepts classification mismatch, and missing README documentation.

## 1. Strengths

- Shared `question_tags` functions centralize association, labeling, hiding, and context composition.
- Model preface positions derive from existing gaps without shifting question anchors or double-counting rows.
- Regeneration tests exercise completed responses for both adjacent exchanges and cursor selection on the preface.
- Context tests cover parsed/live parity, anonymous tags, file references, and raw-request preservation.

## 2. Critical findings

**Exchange movement does not preserve preface ownership — ARCH-PURPOSE, ARCH-DRY.**

[init.lua:4242](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:4242) starts pruning at the question marker, leaving its preface in the parent. [exchange_clipboard.lua:23](/Users/xianxu/workspace/parley.nvim/lua/parley/exchange_clipboard.lua:23) likewise excludes the current preface and includes the next exchange’s preface; selection and paste calculations repeat those boundaries.

A headless probe with two tagged questions confirmed:

- Cutting the first question includes `@@second@@` but excludes `@@first@@`.
- Cutting the second question excludes its tag.
- Selecting only the second preface selects exchange 1.
- Pasting after exchange 1 inserts between the second preface and its question.

Use a shared semantic exchange-start calculation for prune, cut, visual selection, and paste. Add regression tests covering that complete consumer set.

**The Core concepts table incorrectly classifies `parse_chat` as PURE — ARCH-PURE.**

[Plan:22](/Users/xianxu/workspace/parley.nvim/workshop/plans/000240-question-tag-ownership-plan.md:22) declares `parse_chat` PURE, but [chat_parser.lua:317](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:317) calls `logger.debug`; [logger.lua:93](/Users/xianxu/workspace/parley.nvim/lua/parley/logger.lua:93) opens and writes a file. Parser tests execute this dependency directly.

This contradicts the required no-IO classification. Reclassify the existing parser as INTEGRATION and document its pure association dependency, or extract logging from the parser. Append a plan revision explaining the correction.

## 3. Important findings

**README update appears missing for outline-tag syntax.**

[README.md:39](/Users/xianxu/workspace/parley.nvim/README.md:39) is unchanged in the pinned range. The new user-authored `@@label@@` and `@@_@@` conventions need a brief explanation covering adjacency, hiding, and following-question context ownership. Atlas and generated help updates are present.

## 4. Minor findings

None.

## 5. Test coverage notes

Fresh verification passed:

- `make test-spec SPEC=ui/outline`
- Parser: 70 tests.
- Message builders: 84 tests.
- Response integration: 73 tests.

The exchange-editing probe exposes behavior those suites do not cover. Full-suite results and performance measurements reported by the implementor were not independently rerun.

## 6. Architectural notes

| Principle | Result |
|---|---|
| ARCH-DRY | **Flag:** exchange ownership boundaries remain duplicated across editing consumers. |
| ARCH-PURE | **Flag:** parser classification contradicts its logging IO. |
| ARCH-PURPOSE | **Flag:** question ownership does not survive exchange movement. |
| ARCH-MOCK | **Pass:** no new external dependency; regeneration exercises the existing transport seam. |
| ARCH-CONSTRAINTS | **Pass by inspection:** linear scans, transient metadata, no new per-token work; timing remains unverified. |
| ARCH-SECURE | **Pass:** reference handling reuses existing extraction/loading policy; no new credential surface. |
| ARCH-ORDER | **Pass:** no new asynchronous state machine; preface positions derive from existing model state. |
| ARCH-FUNERAL | **Pass:** metadata dies with parsed/model objects; no new durable runtime artifact. |

## 7. Plan revision recommendations

Append `## Revisions` entries that:

- Enumerate prune, cut, visual selection, and paste as consumers of semantic preface ownership, with regression coverage.
- Correct `parse_chat`’s classification and explain its logging boundary.

```findings
findings:
  - id: new
    severity: Critical
    family: exchange-ownership-consumer-completeness
    title: |
      Exchange editing still assigns prefaces to the preceding exchange
    detail: |
      init.lua:4242 prunes from question.line_start; exchange_clipboard.lua:23-100 uses question starts for cut, selection, and paste boundaries. A headless probe confirmed that cutting exchange 1 takes exchange 2's tag, cutting exchange 2 omits its own tag, and selecting its preface selects exchange 1. ARCH-PURPOSE/ARCH-DRY: share semantic exchange boundaries and cover all movement consumers with regression tests.
  - id: new
    severity: Critical
    family: core-concept-purity-classification
    title: |
      The plan declares parse_chat PURE despite direct logging IO
    detail: |
      workshop/plans/000240-question-tag-ownership-plan.md:22 declares parse_chat PURE, but chat_parser.lua:317 calls logger.debug, whose logger.lua:93 implementation opens and writes a file. ARCH-PURE: classify the existing parser as INTEGRATION or move logging outside its pure core, and append a plan revision.
  - id: new
    severity: Important
    family: user-facing-surface-documentation
    title: |
      README update is missing for the new outline-tag conventions
    detail: |
      README.md is unchanged in the pinned range despite introducing user-authored @@label@@ and @@_@@ behavior. Add a concise explanation of strict adjacency, outline visibility, and following-question context ownership; atlas and generated help already document this surface.
```

---

## Re-review — 2026-09-14T20:49:58-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 240 — Outline tag conventions: an @@tag@@ immediately before a question labels it; @@_@@ is anonymous and hides itself, or the question it precedes |
| repo | parley.nvim |
| issue file | workshop/issues/000240-outline-tag-labels-question-and-anonymous-tag.md |
| boundary | whole-issue close |
| milestone | — |
| window | 25197533d70f3399947d0f789bc8e217c6abfd2d..1888d4b2454f38da5309b414f5296bb25bc9c0af |
| command | sdlc close --issue 240 |
| reviewer | codex |
| timestamp | 2026-09-14T20:49:58-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change implements the revised exchange-preface design and addresses all three prior findings. Semantic ownership now reaches editing and scoped-context consumers while preserving physical question anchors. No blocking findings remain.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      question_tags.semantic_start is shared by clipboard ranges, selection, paste, prune, lookup, definition context and drill-in extraction. Relevant regression suites pass. Replacing its implementation with question.line_start in a scratch copy makes all six new clipboard regressions fail.
  - id: BR-2
    disposition: addressed
    note: |
      The plan's Core concepts table now classifies parse_chat as INTEGRATION, with an appended boundary-review revision. This matches chat_parser.lua's logger.debug call and logger.lua:93's file-writing implementation.
  - id: BR-3
    disposition: addressed
    note: |
      README.md:51-54 now explains strict adjacency, anonymous-question hiding and following-question AI-context ownership. The description agrees with question_tags.apply_outline and compose_question; atlas documentation covers standalone anonymous tags and filtering.
```

### 1. Strengths

- Shared association and semantic-boundary helpers keep outline, context and editing behavior consistent.
- Live preface positions derive from existing gaps, preserving question-block identity without double-counting rows.
- Tests exercise real parser/model behavior, regeneration completion, clipboard movement and scoped context.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

None.

### 5. Test coverage

All **13 changed spec files passed: 430 tests**. The definition suite passed when rerun separately after a parallel cache-directory collision. Six clipboard regressions failed with the semantic-boundary fix removed. Pinned `git diff --check` passed.

The full repository suite and performance benchmark were not independently rerun.

### 6. Architecture

- **ARCH-DRY — pass:** shared association, composition and semantic-start helpers.
- **ARCH-PURE — pass:** pure helpers use direct tests; parser classification reflects logging IO.
- **ARCH-PURPOSE — pass:** ownership reaches the reviewed context and movement consumers.
- **ARCH-MOCK — pass:** no new external dependency; existing test seams remain.
- **ARCH-CONSTRAINTS — pass:** linear scans, transient metadata, no added per-token work.
- **ARCH-SECURE — pass:** existing reference extraction and loading policies remain in use.
- **ARCH-ORDER — pass:** no new asynchronous state; regeneration tests exercise completion.
- **ARCH-FUNERAL — pass:** preface metadata dies with existing parsed/model objects; no new durable artifacts.

### 7. Plan revisions

No additional revisions required.
