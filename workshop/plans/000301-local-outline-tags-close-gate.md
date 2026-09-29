---
gate: boundary-review
issue: 301
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-29T11:11:28-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Drop empty text blocks and messages after local-tag projection
          detail: lua/parley/chat_respond.lua:797 retains a text block whose context_text is empty. A tag-only text section before a tool call produces an empty text block in the actual Anthropic payload, whereas the live builder omits it. Normalize empty projected content consistently across builders and test tag-only questions, answers, and text sections around tools. ARCH-PURPOSE.
          family: projection-preserves-message-validity
          round: 1
        - id: BR-2
          severity: Critical
          title: Recognize fences opened after the question speaker prefix
          detail: lua/parley/question_tags.lua:19 misses a fence opener on the question's speaker line. A question beginning with the user prefix followed by three backticks loses a subsequent @@literal@@ row despite its closing fence. Preserve original-row tag classification while recognizing question-content fence syntax; cover parsed/live paths and custom prefixes. ARCH-PURPOSE.
          family: projection-preserves-fenced-literals
          round: 1
        - id: BR-3
          severity: Important
          title: Exercise tag projection through both changed topic-request callers
          detail: lua/parley/chat_respond.lua:1673 and lua/parley/init.lua:4450 change automatic-topic and ChatPrune topic inputs without caller-level regression coverage. Capture both outgoing requests and assert local-tag exclusion and literal preservation; removing either caller's projection must fail its test.
          family: changed-consumer-regression-coverage
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#301 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T11:11:28-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `projection-preserves-message-validity` Drop empty text blocks and messages after local-tag projection
  lua/parley/chat_respond.lua:797 retains a text block whose context_text is empty. A tag-only text section before a tool call produces an empty text block in the actual Anthropic payload, whereas the live builder omits it. Normalize empty projected content consistently across builders and test tag-only questions, answers, and text sections around tools. ARCH-PURPOSE.
- **BR-2** [Critical] `projection-preserves-fenced-literals` Recognize fences opened after the question speaker prefix
  lua/parley/question_tags.lua:19 misses a fence opener on the question's speaker line. A question beginning with the user prefix followed by three backticks loses a subsequent @@literal@@ row despite its closing fence. Preserve original-row tag classification while recognizing question-content fence syntax; cover parsed/live paths and custom prefixes. ARCH-PURPOSE.
- **BR-3** [Important] `changed-consumer-regression-coverage` Exercise tag projection through both changed topic-request callers
  lua/parley/chat_respond.lua:1673 and lua/parley/init.lua:4450 change automatic-topic and ChatPrune topic inputs without caller-level regression coverage. Capture both outgoing requests and assert local-tag exclusion and literal preservation; removing either caller's projection must fail its test.

## Open findings

- **BR-1** [Critical] `projection-preserves-message-validity` Drop empty text blocks and messages after local-tag projection
- **BR-2** [Critical] `projection-preserves-fenced-literals` Recognize fences opened after the question speaker prefix
- **BR-3** [Important] `changed-consumer-regression-coverage` Exercise tag projection through both changed topic-request callers
