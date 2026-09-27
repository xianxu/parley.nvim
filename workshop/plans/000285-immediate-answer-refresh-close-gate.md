---
gate: boundary-review
issue: 285
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T16:53:46-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Re-ask payloads can retain stale tool-call answer blocks
          detail: '`input_parsed` is deep-copied before `exchange.answer = nil`, so target answers containing tool_use/tool_result blocks remain eligible for inclusion in `build_messages`; clear the target answer in the payload snapshot and add a regression test.'
          family: resubmit-capture-excludes-target-answer
          round: 1
        - id: BR-2
          severity: Important
          title: Production cancellation and admission cleanup lack regression coverage
          detail: The new lifecycle cleanup is tested only through direct document helpers, not through response cancellation or failed admission; add integration tests that prove no pending snapshot survives either path.
          family: pending-snapshot-terminal-path-coverage
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-26T17:00:18-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The target answer is cleared from input_parsed, but no regression test exercises a re-ask containing tool_use/tool_result blocks; the required behavior-changing evidence is absent.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Production cancellation now has integration coverage, but failed-admission cleanup still has no regression test, so the finding is only partially addressed.
          round: 2
      findings:
        - id: BR-3
          severity: Critical
          title: Overlapping re-asks can clear another attempt's pending snapshot
          detail: The pending slot is stored by entity with generation=nil and release clears by entity plus nil generation; an earlier response can therefore retire a later response's snapshot before its generation adopts it. Add per-attempt ownership/token matching and an overlapping re-ask regression test. ARCH-ORDER, ARCH-FUNERAL.
          family: pending-snapshot-generation-ownership
          round: 2
        - id: BR-4
          severity: Minor
          title: Footer result is overwritten before use
          detail: The assignment at lua/parley/chat_respond.lua:1516 is overwritten at line 1529; remove it to restore a clean lint run.
          family: dead-intermediate-assignment
          round: 2
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-26T20:25:17-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: chat_respond_spec.lua:160 verifies stale tool calls/results are absent. Removing the payload-snapshot clearing in memory makes this regression fail at line 174.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Production cancellation and source-edit admission rejection have coverage. Removing pending cleanup in memory makes the rejection regression fail at chat_respond_spec.lua:190 with one orphaned snapshot.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Owner checks prevent mismatched clearing/adoption; duplicate submissions are rejected before mutation across five tested phases. Disabling owner matching in memory makes document_previous_answer_spec.lua:70 fail.
          round: 3
        - id: BR-4
          disposition: addressed
          note: The initial footer value now bounds deletion before reassignment. make lint passes with zero warnings and errors across 656 files.
          round: 3
      findings:
        - id: BR-5
          severity: Important
          title: New refusal token is absent from the shared vocabulary
          detail: lua/parley/chat_respond.lua:1534 emits exchange identity unavailable, which lua/parley/refusal.lua does not register. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing question identity unavailable token or register actionable wording. ARCH-DRY.
          family: refusal-producers-use-shared-vocabulary
          round: 3
        - id: BR-6
          severity: Important
          title: Existing duplicate-submission test contradicts the new admission contract
          detail: tests/integration/chat_scoped_response_spec.lua:63 requires a non-nil second session and later cancellation, but chat_respond.lua:1504 now rejects synchronously. Update the expectation to immediate refusal while retaining assertions that no second provider call occurs and the original writer completes.
          family: regression-tests-follow-public-contract
          round: 3
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#285 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T16:53:46-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `resubmit-capture-excludes-target-answer` Re-ask payloads can retain stale tool-call answer blocks
  `input_parsed` is deep-copied before `exchange.answer = nil`, so target answers containing tool_use/tool_result blocks remain eligible for inclusion in `build_messages`; clear the target answer in the payload snapshot and add a regression test.
- **BR-2** [Important] `pending-snapshot-terminal-path-coverage` Production cancellation and admission cleanup lack regression coverage
  The new lifecycle cleanup is tested only through direct document helpers, not through response cancellation or failed admission; add integration tests that prove no pending snapshot survives either path.

## Round 2 — 2026-09-26T17:00:18-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The target answer is cleared from input_parsed, but no regression test exercises a re-ask containing tool_use/tool_result blocks; the required behavior-changing evidence is absent.
- BR-2 — not-addressed — Production cancellation now has integration coverage, but failed-admission cleanup still has no regression test, so the finding is only partially addressed.

### Raised

- **BR-3** [Critical] `pending-snapshot-generation-ownership` Overlapping re-asks can clear another attempt's pending snapshot
  The pending slot is stored by entity with generation=nil and release clears by entity plus nil generation; an earlier response can therefore retire a later response's snapshot before its generation adopts it. Add per-attempt ownership/token matching and an overlapping re-ask regression test. ARCH-ORDER, ARCH-FUNERAL.
- **BR-4** [Minor] `dead-intermediate-assignment` Footer result is overwritten before use
  The assignment at lua/parley/chat_respond.lua:1516 is overwritten at line 1529; remove it to restore a clean lint run.

## Round 3 — 2026-09-26T20:25:17-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — chat_respond_spec.lua:160 verifies stale tool calls/results are absent. Removing the payload-snapshot clearing in memory makes this regression fail at line 174.
- BR-2 — addressed — Production cancellation and source-edit admission rejection have coverage. Removing pending cleanup in memory makes the rejection regression fail at chat_respond_spec.lua:190 with one orphaned snapshot.
- BR-3 — addressed — Owner checks prevent mismatched clearing/adoption; duplicate submissions are rejected before mutation across five tested phases. Disabling owner matching in memory makes document_previous_answer_spec.lua:70 fail.
- BR-4 — addressed — The initial footer value now bounds deletion before reassignment. make lint passes with zero warnings and errors across 656 files.

### Raised

- **BR-5** [Important] `refusal-producers-use-shared-vocabulary` New refusal token is absent from the shared vocabulary
  lua/parley/chat_respond.lua:1534 emits exchange identity unavailable, which lua/parley/refusal.lua does not register. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing question identity unavailable token or register actionable wording. ARCH-DRY.
- **BR-6** [Important] `regression-tests-follow-public-contract` Existing duplicate-submission test contradicts the new admission contract
  tests/integration/chat_scoped_response_spec.lua:63 requires a non-nil second session and later cancellation, but chat_respond.lua:1504 now rejects synchronously. Update the expectation to immediate refusal while retaining assertions that no second provider call occurs and the original writer completes.

## Open findings

- **BR-5** [Important] `refusal-producers-use-shared-vocabulary` New refusal token is absent from the shared vocabulary
- **BR-6** [Important] `regression-tests-follow-public-contract` Existing duplicate-submission test contradicts the new admission contract
