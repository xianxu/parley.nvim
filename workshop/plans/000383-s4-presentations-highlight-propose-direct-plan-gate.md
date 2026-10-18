---
gate: plan-quality
issue: 383
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 87d80ab8-6499-431c-8637-c421f155c76c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000383"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 93be2f49f3a8ca066b693ae4d42299a2591dfbe3
            slot: parley.nvim:3
            requested_at: "2026-10-18T11:49:03.253732Z"
          phase: finished
          pid: 42714
          started_at: "2026-10-18T11:49:03.459571Z"
          finished_at: "2026-10-18T11:50:06.26601Z"
          session_id: ef12293d-4b6f-4c23-b8e1-ef727bd5d2a5
          outcome: returned
      "n": 1
      timestamp: "2026-10-18T04:50:06-07:00"
      agent: claude
      findings:
        - kind: defect
          id: PQ-1
          severity: Minor
          title: Fake --owe stamps At at 1-second resolution, so LastSubmit > Round.at can tie and flake the Cleared/reopen spec
          detail: fake_couch_registry.py:64 uses %SZ (seconds). A round seeded at "now" and submitted in the same second yields Cleared=false under a strict '>'. Stamp sub-second precision, or have specs seed `at` in the past.
          family: timestamp-resolution-ordering
          round: 1
        - kind: defect
          id: PQ-2
          severity: Minor
          title: Tasks enumerate test cases in prose instead of one adversarial strategy line for presentation.decorations
          detail: 'Replace the case lists with: decorations over arbitrary rounds/lines, fuzzed with malformed or out-of-range spans, multibyte/CRLF text and empty or duplicate `new` text; the guard is that every output position lies within `lines` and nothing raises.'
          family: test-plan-enumeration
          round: 1
        - kind: defect
          id: PQ-3
          severity: Minor
          title: Round span positions from Couch are trusted on hash match with no shape/range validation or strict=false extmarks
          detail: A hand-edited sidecar or a Couch bug can put a column past the end of a line, and nvim_buf_set_extmark throws on the reload path. Validate span shape and range in the pure layer and drop bad spans, or use strict=false as highlight_footnote_span does.
          family: untrusted-input-typed-at-boundary
          round: 1
        - kind: defect
          id: PQ-4
          severity: Minor
          title: No ARCH-CONSTRAINTS budget for the per-keystroke on_lines re-derive and the per-reply re-anchor search
          detail: vim.schedule defers but does not debounce. Classify the keystroke path, coalesce to one pending re-derive per buffer, and bound the span count or document size the re-anchor search is expected to handle.
          family: missing-operating-envelope
          round: 1
      blocked: false
content_hash: 8c257557739201806e1054501010ed1c252c095fd5d577482ace18ba9bfaa8e8
---

# Gate ledger — parley.nvim#383 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T04:50:06-07:00 (claude) — passed

### Raised

- **PQ-1** [Minor] `timestamp-resolution-ordering` (kind: defect) Fake --owe stamps At at 1-second resolution, so LastSubmit > Round.at can tie and flake the Cleared/reopen spec
  fake_couch_registry.py:64 uses %SZ (seconds). A round seeded at "now" and submitted in the same second yields Cleared=false under a strict '>'. Stamp sub-second precision, or have specs seed `at` in the past.
- **PQ-2** [Minor] `test-plan-enumeration` (kind: defect) Tasks enumerate test cases in prose instead of one adversarial strategy line for presentation.decorations
  Replace the case lists with: decorations over arbitrary rounds/lines, fuzzed with malformed or out-of-range spans, multibyte/CRLF text and empty or duplicate `new` text; the guard is that every output position lies within `lines` and nothing raises.
- **PQ-3** [Minor] `untrusted-input-typed-at-boundary` (kind: defect) Round span positions from Couch are trusted on hash match with no shape/range validation or strict=false extmarks
  A hand-edited sidecar or a Couch bug can put a column past the end of a line, and nvim_buf_set_extmark throws on the reload path. Validate span shape and range in the pure layer and drop bad spans, or use strict=false as highlight_footnote_span does.
- **PQ-4** [Minor] `missing-operating-envelope` (kind: defect) No ARCH-CONSTRAINTS budget for the per-keystroke on_lines re-derive and the per-reply re-anchor search
  vim.schedule defers but does not debounce. Classify the keystroke path, coalesce to one pending re-derive per buffer, and bound the span count or document size the re-anchor search is expected to handle.

## Open findings

- **PQ-1** [Minor] `timestamp-resolution-ordering` (kind: defect) Fake --owe stamps At at 1-second resolution, so LastSubmit > Round.at can tie and flake the Cleared/reopen spec
- **PQ-2** [Minor] `test-plan-enumeration` (kind: defect) Tasks enumerate test cases in prose instead of one adversarial strategy line for presentation.decorations
- **PQ-3** [Minor] `untrusted-input-typed-at-boundary` (kind: defect) Round span positions from Couch are trusted on hash match with no shape/range validation or strict=false extmarks
- **PQ-4** [Minor] `missing-operating-envelope` (kind: defect) No ARCH-CONSTRAINTS budget for the per-keystroke on_lines re-derive and the per-reply re-anchor search
