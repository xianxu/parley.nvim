---
gate: boundary-review
issue: 240
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-14T20:42:39-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Exchange editing still assigns prefaces to the preceding exchange
          detail: 'init.lua:4242 prunes from question.line_start; exchange_clipboard.lua:23-100 uses question starts for cut, selection, and paste boundaries. A headless probe confirmed that cutting exchange 1 takes exchange 2''s tag, cutting exchange 2 omits its own tag, and selecting its preface selects exchange 1. ARCH-PURPOSE/ARCH-DRY: share semantic exchange boundaries and cover all movement consumers with regression tests.'
          family: exchange-ownership-consumer-completeness
          round: 1
        - id: BR-2
          severity: Critical
          title: The plan declares parse_chat PURE despite direct logging IO
          detail: 'workshop/plans/000240-question-tag-ownership-plan.md:22 declares parse_chat PURE, but chat_parser.lua:317 calls logger.debug, whose logger.lua:93 implementation opens and writes a file. ARCH-PURE: classify the existing parser as INTEGRATION or move logging outside its pure core, and append a plan revision.'
          family: core-concept-purity-classification
          round: 1
        - id: BR-3
          severity: Important
          title: README update is missing for the new outline-tag conventions
          detail: README.md is unchanged in the pinned range despite introducing user-authored @@label@@ and @@_@@ behavior. Add a concise explanation of strict adjacency, outline visibility, and following-question context ownership; atlas and generated help already document this surface.
          family: user-facing-surface-documentation
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T20:49:58-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: question_tags.semantic_start is shared by clipboard ranges, selection, paste, prune, lookup, definition context and drill-in extraction. Relevant regression suites pass. Replacing its implementation with question.line_start in a scratch copy makes all six new clipboard regressions fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The plan's Core concepts table now classifies parse_chat as INTEGRATION, with an appended boundary-review revision. This matches chat_parser.lua's logger.debug call and logger.lua:93's file-writing implementation.
          round: 2
        - id: BR-3
          disposition: addressed
          note: README.md:51-54 now explains strict adjacency, anonymous-question hiding and following-question AI-context ownership. The description agrees with question_tags.apply_outline and compose_question; atlas documentation covers standalone anonymous tags and filtering.
          round: 2
      blocked: false
---

# Gate ledger — parley.nvim#240 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T20:42:39-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `exchange-ownership-consumer-completeness` Exchange editing still assigns prefaces to the preceding exchange
  init.lua:4242 prunes from question.line_start; exchange_clipboard.lua:23-100 uses question starts for cut, selection, and paste boundaries. A headless probe confirmed that cutting exchange 1 takes exchange 2's tag, cutting exchange 2 omits its own tag, and selecting its preface selects exchange 1. ARCH-PURPOSE/ARCH-DRY: share semantic exchange boundaries and cover all movement consumers with regression tests.
- **BR-2** [Critical] `core-concept-purity-classification` The plan declares parse_chat PURE despite direct logging IO
  workshop/plans/000240-question-tag-ownership-plan.md:22 declares parse_chat PURE, but chat_parser.lua:317 calls logger.debug, whose logger.lua:93 implementation opens and writes a file. ARCH-PURE: classify the existing parser as INTEGRATION or move logging outside its pure core, and append a plan revision.
- **BR-3** [Important] `user-facing-surface-documentation` README update is missing for the new outline-tag conventions
  README.md is unchanged in the pinned range despite introducing user-authored @@label@@ and @@_@@ behavior. Add a concise explanation of strict adjacency, outline visibility, and following-question context ownership; atlas and generated help already document this surface.

## Round 2 — 2026-09-14T20:49:58-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — question_tags.semantic_start is shared by clipboard ranges, selection, paste, prune, lookup, definition context and drill-in extraction. Relevant regression suites pass. Replacing its implementation with question.line_start in a scratch copy makes all six new clipboard regressions fail.
- BR-2 — addressed — The plan's Core concepts table now classifies parse_chat as INTEGRATION, with an appended boundary-review revision. This matches chat_parser.lua's logger.debug call and logger.lua:93's file-writing implementation.
- BR-3 — addressed — README.md:51-54 now explains strict adjacency, anonymous-question hiding and following-question AI-context ownership. The description agrees with question_tags.apply_outline and compose_question; atlas documentation covers standalone anonymous tags and filtering.

## Open findings

(none — every finding has been disposed)
