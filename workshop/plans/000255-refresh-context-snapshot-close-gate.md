---
gate: boundary-review
issue: 255
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T19:49:37-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Duplicate submission erases a streaming answer before ownership admission
          detail: 'lua/parley/chat_respond.lua:1512–1515 replaces the previous-answer slot and deletes output before admission. A deterministic scratch test fails on HEAD after partial output, but passes with the BASE chat_respond.lua: the duplicate must preserve the active writer and its text. Route mutation through admitted ownership and cover duplicate submissions before and after output (ARCH-ORDER, ARCH-PURPOSE).'
          family: mutation-before-admission
          round: 1
        - id: BR-2
          severity: Important
          title: README and atlas describe the superseded refresh lifecycle
          detail: README.md:74–75 promises old-answer visibility until replacement output, whereas chat_respond.lua:1515 deletes it immediately. atlas/chat/transcript_truth.md:59 omits pending previous-answer ownership before generation admission. Update both passages to match the corrected lifecycle.
          family: lifecycle-documentation-drift
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-26T20:24:55-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: chat_respond.lua:1494–1505 rejects duplicates before snapshot publication or deletion. All five duplicate regressions pass on HEAD and fail when this guard is removed in a scratch copy.
          round: 2
        - id: BR-2
          disposition: addressed
          note: README.md:74–78 now describes immediate removal on accepted refresh and preservation on duplicate submission. atlas/chat/transcript_truth.md:59 documents pending ownership, adoption, and cleanup, matching chat_respond.lua and document/init.lua.
          round: 2
      findings:
        - id: BR-3
          severity: Important
          title: New identity refusal bypasses the shared refusal vocabulary
          detail: lua/parley/chat_respond.lua:1534 introduces "exchange identity unavailable", which refusal.lua does not recognize; it falls through to the generic unexpected-error message. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing "question identity unavailable" token or register an appropriate explanation and recovery action (ARCH-DRY).
          family: refusal-vocabulary-registration
          round: 2
        - id: BR-4
          severity: Important
          title: Existing lifecycle tests still assume the superseded submission timing
          detail: tests/integration/chat_onboarding_capture_spec.lua:43 uses a row removed by immediate refresh, and :105 deletes the following question because its fixed range is now stale. tests/integration/chat_scoped_response_spec.lua:63 expects duplicates to return a session, although they now return nil immediately. All three fail on HEAD and pass with BASE chat_respond.lua restored in scratch. Resolve fixture rows from current content and assert immediate rejection while retaining the writer-preservation checks.
          family: regression-suite-contract-drift
          round: 2
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-26T21:11:22-07:00"
      agent: codex
      dispose:
        - id: BR-3
          disposition: addressed
          note: chat_respond.lua:1534 now uses the registered "question identity unavailable" token. All six refusal vocabulary checks pass; restoring the prior token makes the vocabulary check fail.
          round: 3
        - id: BR-4
          disposition: addressed
          note: Onboarding and scoped-response suites pass all 19 cases. Restoring the prior fixtures reproduces both onboarding failures and the duplicate-submission failure; writer-preservation assertions remain.
          round: 3
        - id: BR-1
          disposition: addressed
          note: Duplicate admission precedes deletion. Passing regressions cover waiting, streaming, moved markers, snapshot preservation, continued output, and later resubmission.
          round: 3
        - id: BR-2
          disposition: addressed
          note: README.md describes immediate removal and duplicate preservation; atlas/chat/lifecycle.md and transcript_truth.md describe pending ownership, generation adoption, and cleanup consistently with the implementation.
          round: 3
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#255 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T19:49:37-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `mutation-before-admission` Duplicate submission erases a streaming answer before ownership admission
  lua/parley/chat_respond.lua:1512–1515 replaces the previous-answer slot and deletes output before admission. A deterministic scratch test fails on HEAD after partial output, but passes with the BASE chat_respond.lua: the duplicate must preserve the active writer and its text. Route mutation through admitted ownership and cover duplicate submissions before and after output (ARCH-ORDER, ARCH-PURPOSE).
- **BR-2** [Important] `lifecycle-documentation-drift` README and atlas describe the superseded refresh lifecycle
  README.md:74–75 promises old-answer visibility until replacement output, whereas chat_respond.lua:1515 deletes it immediately. atlas/chat/transcript_truth.md:59 omits pending previous-answer ownership before generation admission. Update both passages to match the corrected lifecycle.

## Round 2 — 2026-09-26T20:24:55-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — chat_respond.lua:1494–1505 rejects duplicates before snapshot publication or deletion. All five duplicate regressions pass on HEAD and fail when this guard is removed in a scratch copy.
- BR-2 — addressed — README.md:74–78 now describes immediate removal on accepted refresh and preservation on duplicate submission. atlas/chat/transcript_truth.md:59 documents pending ownership, adoption, and cleanup, matching chat_respond.lua and document/init.lua.

### Raised

- **BR-3** [Important] `refusal-vocabulary-registration` New identity refusal bypasses the shared refusal vocabulary
  lua/parley/chat_respond.lua:1534 introduces "exchange identity unavailable", which refusal.lua does not recognize; it falls through to the generic unexpected-error message. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing "question identity unavailable" token or register an appropriate explanation and recovery action (ARCH-DRY).
- **BR-4** [Important] `regression-suite-contract-drift` Existing lifecycle tests still assume the superseded submission timing
  tests/integration/chat_onboarding_capture_spec.lua:43 uses a row removed by immediate refresh, and :105 deletes the following question because its fixed range is now stale. tests/integration/chat_scoped_response_spec.lua:63 expects duplicates to return a session, although they now return nil immediately. All three fail on HEAD and pass with BASE chat_respond.lua restored in scratch. Resolve fixture rows from current content and assert immediate rejection while retaining the writer-preservation checks.

## Round 3 — 2026-09-26T21:11:22-07:00 (codex) — passed

### Disposed

- BR-3 — addressed — chat_respond.lua:1534 now uses the registered "question identity unavailable" token. All six refusal vocabulary checks pass; restoring the prior token makes the vocabulary check fail.
- BR-4 — addressed — Onboarding and scoped-response suites pass all 19 cases. Restoring the prior fixtures reproduces both onboarding failures and the duplicate-submission failure; writer-preservation assertions remain.
- BR-1 — addressed — Duplicate admission precedes deletion. Passing regressions cover waiting, streaming, moved markers, snapshot preservation, continued output, and later resubmission.
- BR-2 — addressed — README.md describes immediate removal and duplicate preservation; atlas/chat/lifecycle.md and transcript_truth.md describe pending ownership, generation adoption, and cleanup consistently with the implementation.

## Open findings

(none — every finding has been disposed)
