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
    - "n": 2
      timestamp: "2026-09-29T11:27:42-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Empty-content regression passes and fails when the projected text-block omission guard is removed in memory.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Balanced speaker-line fences are fixed, but a speaker-line fence terminated by the next question still loses its final literal tag through question_tags.lua:56 preface association and line 71 composition.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Both caller-level request tests pass; removing automatic-answer, prune-question, or prune-answer projection independently makes its regression fail.
          round: 2
      findings:
        - id: BR-4
          severity: Critical
          title: Mixed delimiter runs incorrectly close fences and invert tag projection
          detail: 'question_tags.lua:26 accepts ```~~~ as a backtick closer, deleting a subsequent fenced literal and retaining a local tag after the real closer. This is the 2nd finding in this family: establish one fence rule across projection and association, and test delimiter character, width, trailing content, speaker-line openers, and turn-boundary termination. ARCH-DRY, ARCH-PURPOSE.'
          family: projection-preserves-fenced-literals
          round: 2
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

## Round 2 — 2026-09-29T11:27:42-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Empty-content regression passes and fails when the projected text-block omission guard is removed in memory.
- BR-2 — not-addressed — Balanced speaker-line fences are fixed, but a speaker-line fence terminated by the next question still loses its final literal tag through question_tags.lua:56 preface association and line 71 composition.
- BR-3 — addressed — Both caller-level request tests pass; removing automatic-answer, prune-question, or prune-answer projection independently makes its regression fail.

### Raised

- **BR-4** [Critical] `projection-preserves-fenced-literals` Mixed delimiter runs incorrectly close fences and invert tag projection
  question_tags.lua:26 accepts ```~~~ as a backtick closer, deleting a subsequent fenced literal and retaining a local tag after the real closer. This is the 2nd finding in this family: establish one fence rule across projection and association, and test delimiter character, width, trailing content, speaker-line openers, and turn-boundary termination. ARCH-DRY, ARCH-PURPOSE.

## Open findings

- **BR-2** [Critical] `projection-preserves-fenced-literals` Recognize fences opened after the question speaker prefix
- **BR-4** [Critical] `projection-preserves-fenced-literals` Mixed delimiter runs incorrectly close fences and invert tag projection
