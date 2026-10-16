---
gate: boundary-review
issue: 242
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-16T07:43:38-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
          detail: |-
            2nd finding in this family. Rule: each proof names, per case, the observable both trees expose (which callback fires and with what argument), and checks it on the branch before reading the old tree's result. _ending_notice treats class cap as advisory text, so the cap case may need to assert the notice or the stop_reason path rather than the error callback.
            (carried from plan-quality PQ-8, deferred to the boundary review)
          family: regression-proof-runs-on-old-tree
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6061256b-84ce-4528-8579-08bde2bd6fb2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/634d322e8b7cda1d
            reviewed_head: ba0d3021074610bd8de5ad44097bc53c15bd8884
            slot: parley.nvim:4
            requested_at: "2026-10-16T14:40:48.035655Z"
          phase: finished
          pid: 9302
          started_at: "2026-10-16T14:40:48.188207Z"
          finished_at: "2026-10-16T14:43:35.481583Z"
          session_id: 0a2f26f5-caa1-4d9c-910a-7b14cd4c16cb
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: ba0d3021074610bd8de5ad44097bc53c15bd8884
        tracker_head: 4e3d162a34567b637305abe15dc733009f18d9c0
        branch_point: a53472921f064c68ee2992246396794b593d01b9
        since: "2026-10-16T07:13:14-07:00"
        until: "2026-10-16T07:37:07-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T07:13:14-07:00"
              end: "2026-10-16T07:37:07-07:00"
              began: "2026-10-16T07:13:14-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 5d7d716b92ff95fbeefbc03b7a8c6f0d9c44e4782ce4998f3935abe69c393262
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 13314746
              windows:
                - start: "2026-10-16T07:13:14-07:00"
                  end: "2026-10-16T07:37:07-07:00"
      "n": 2
      timestamp: "2026-10-16T07:43:38-07:00"
      dispatched: "2026-10-16T07:40:48-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-2
          severity: Important
          title: Task 2's tests/unit/fake_provider_spec.lua (behaviour table, split invariant, per-mode shell, request-log gating) is not delivered
          detail: The plan's Task 2 names this spec and its four checks. The file does not exist at head, and no Revisions entry drops it, so the pure behaviour and split functions (sse_dialects.py:103,127) have no direct test (ARCH-PURPOSE, ARCH-PURE). Add the spec (pure checks via python3 -I, as sse_dialects_spec already does) or record a revision.
          family: plan-item-undelivered
          round: 2
        - kind: defect
          id: BR-3
          severity: Important
          title: S3 asserts dispatcher._classify_ending directly instead of the user-visible in-band notice the dispatch path emits
          detail: provider_anthropic_spec.lua:66 re-runs the classifier on qt, so it passes even if the dispatcher drops the report. In fact _ending_notice returns a warning-level 'answer is TRUNCATED ... in-band — Overloaded' (dispatcher.lua:362-370) that the dispatcher logs (:856-863). Assert out.warnings contains 'in-band — Overloaded', as S5 does, and correct the Log/plan note that claims nothing is logged.
          family: test-oracle-bypasses-path
          round: 2
        - kind: defect
          id: BR-4
          severity: Important
          title: 'S7a''s ''partial answer kept'' assertion cannot fail: qt.response starts as an empty string, never nil'
          detail: provider_anthropic_spec.lua:101 checks out.qt.response ~= nil, but dispatcher.lua:479 initializes response to "". The 600-byte cut contains exactly the first delta, so assert.equals('Hello,', out.qt.response).
          family: vacuous-assertion
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: S6 does not assert that the byte split reached the reader; the vocabulary entry '"stop_reason"' also matches message_start's null field
          detail: A probe measured 79 reader calls with every_byte against 1 with none, but the spec pins nothing, so curl coalescing would make S6 vacuous without anyone noticing. Count reader calls and assert more than 1, and tighten the stop_reason needle.
          family: vacuous-assertion
          round: 2
        - kind: defect
          id: BR-6
          severity: Minor
          title: 'fake_provider accepts any --mode: unknown modes silently serve text, and a malformed http_ mode raises inside the handler'
          detail: Validate --mode and --split at argparse time, so a typo fails loudly at startup instead of producing a passing ok stream or an empty reply.
          family: unvalidated-fake-config
          round: 2
        - kind: defect
          id: BR-7
          severity: Minor
          title: The plan's --split frames mode, S4's 529/500 variants and an integration no_stop case are not delivered or recorded as deferred
          family: plan-item-undelivered
          round: 2
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#242 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T07:43:38-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `regression-proof-runs-on-old-tree` The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
  2nd finding in this family. Rule: each proof names, per case, the observable both trees expose (which callback fires and with what argument), and checks it on the branch before reading the old tree's result. _ending_notice treats class cap as advisory text, so the cap case may need to assert the notice or the stop_reason path rather than the error callback.
  (carried from plan-quality PQ-8, deferred to the boundary review)

## Round 2 — 2026-10-16T07:43:38-07:00 (claude) — BLOCKED

### Raised

- **BR-2** [Important] `plan-item-undelivered` (kind: defect) Task 2's tests/unit/fake_provider_spec.lua (behaviour table, split invariant, per-mode shell, request-log gating) is not delivered
  The plan's Task 2 names this spec and its four checks. The file does not exist at head, and no Revisions entry drops it, so the pure behaviour and split functions (sse_dialects.py:103,127) have no direct test (ARCH-PURPOSE, ARCH-PURE). Add the spec (pure checks via python3 -I, as sse_dialects_spec already does) or record a revision.
- **BR-3** [Important] `test-oracle-bypasses-path` (kind: defect) S3 asserts dispatcher._classify_ending directly instead of the user-visible in-band notice the dispatch path emits
  provider_anthropic_spec.lua:66 re-runs the classifier on qt, so it passes even if the dispatcher drops the report. In fact _ending_notice returns a warning-level 'answer is TRUNCATED ... in-band — Overloaded' (dispatcher.lua:362-370) that the dispatcher logs (:856-863). Assert out.warnings contains 'in-band — Overloaded', as S5 does, and correct the Log/plan note that claims nothing is logged.
- **BR-4** [Important] `vacuous-assertion` (kind: defect) S7a's 'partial answer kept' assertion cannot fail: qt.response starts as an empty string, never nil
  provider_anthropic_spec.lua:101 checks out.qt.response ~= nil, but dispatcher.lua:479 initializes response to "". The 600-byte cut contains exactly the first delta, so assert.equals('Hello,', out.qt.response).
- **BR-5** [Minor] `vacuous-assertion` (kind: defect) S6 does not assert that the byte split reached the reader; the vocabulary entry '"stop_reason"' also matches message_start's null field
  A probe measured 79 reader calls with every_byte against 1 with none, but the spec pins nothing, so curl coalescing would make S6 vacuous without anyone noticing. Count reader calls and assert more than 1, and tighten the stop_reason needle.
- **BR-6** [Minor] `unvalidated-fake-config` (kind: defect) fake_provider accepts any --mode: unknown modes silently serve text, and a malformed http_ mode raises inside the handler
  Validate --mode and --split at argparse time, so a typo fails loudly at startup instead of producing a passing ok stream or an empty reply.
- **BR-7** [Minor] `plan-item-undelivered` (kind: defect) The plan's --split frames mode, S4's 529/500 variants and an integration no_stop case are not delivered or recorded as deferred

## Open findings

- **BR-1** [Minor] `regression-proof-runs-on-old-tree` The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
- **BR-2** [Important] `plan-item-undelivered` (kind: defect) Task 2's tests/unit/fake_provider_spec.lua (behaviour table, split invariant, per-mode shell, request-log gating) is not delivered
- **BR-3** [Important] `test-oracle-bypasses-path` (kind: defect) S3 asserts dispatcher._classify_ending directly instead of the user-visible in-band notice the dispatch path emits
- **BR-4** [Important] `vacuous-assertion` (kind: defect) S7a's 'partial answer kept' assertion cannot fail: qt.response starts as an empty string, never nil
- **BR-5** [Minor] `vacuous-assertion` (kind: defect) S6 does not assert that the byte split reached the reader; the vocabulary entry '"stop_reason"' also matches message_start's null field
- **BR-6** [Minor] `unvalidated-fake-config` (kind: defect) fake_provider accepts any --mode: unknown modes silently serve text, and a malformed http_ mode raises inside the handler
- **BR-7** [Minor] `plan-item-undelivered` (kind: defect) The plan's --split frames mode, S4's 529/500 variants and an integration no_stop case are not delivered or recorded as deferred
