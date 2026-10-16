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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 677f09f1-15bc-4ff9-83a4-c8f5edd516c6
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f0854e826beaffeb
            reviewed_head: 19bd7c773bd92def62ad64f28922cb001f54bb41
            slot: parley.nvim:4
            requested_at: "2026-10-16T15:00:02.413673Z"
          phase: finished
          pid: 1801
          started_at: "2026-10-16T15:00:02.5775Z"
          finished_at: "2026-10-16T15:02:55.221242Z"
          session_id: 4d04a54f-448d-4144-bd6c-9e2756031514
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 19bd7c773bd92def62ad64f28922cb001f54bb41
        tracker_head: 4e3d162a34567b637305abe15dc733009f18d9c0
        branch_point: a53472921f064c68ee2992246396794b593d01b9
        since: "2026-10-16T07:13:14-07:00"
        until: "2026-10-16T07:53:14-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T07:13:14-07:00"
              end: "2026-10-16T07:53:14-07:00"
              began: "2026-10-16T07:13:14-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: d54c479543ecb92cbc32e636b3d3db64f6dfef0a99bce18d7e9860967c8a8c54
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 14203743
              windows:
                - start: "2026-10-16T07:13:14-07:00"
                  end: "2026-10-16T07:53:14-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T07:40:48-07:00"
              finalized: "2026-10-16T07:43:38-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T08:02:56-07:00"
      dispatched: "2026-10-16T08:00:02-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: run_proofs.sh:764-767 uses cap_empty/inband_error_empty and checks the notice text on each tree; ran it, 6/6 ok.
          round: 3
        - id: BR-2
          disposition: addressed
          note: tests/unit/fake_provider_spec.lua delivers the behaviour table, split invariant, check_mode, a curl per mode and request-log gating; 10/10 pass.
          round: 3
        - id: BR-3
          disposition: addressed
          note: S3 now asserts the warning containing "in-band — Overloaded" (provider_anthropic_spec.lua:578); the issue Log is struck through, but plan.md:226 still carries the retracted claim (see plan revisions).
          round: 3
        - id: BR-4
          disposition: addressed
          note: provider_anthropic_spec.lua:649 asserts equals("Hello,", out.qt.response); passes.
          round: 3
        - id: BR-5
          disposition: addressed
          note: S6 asserts raw_at_first_chunk < the total raw bytes (:612); the vocabulary needle is now '"stop_reason":"end_turn"'.
          round: 3
        - id: BR-6
          disposition: addressed
          note: check_mode/check_split are argparse types (fake_provider:121-122); fake_provider_spec.lua:890 asserts exit 2 for a typo.
          round: 3
        - id: BR-7
          disposition: addressed
          note: The frames split (sse_dialects.py:368), S4 for 429/529/500 (:581) and the no_stop integration case (:636) are delivered and pass.
          round: 3
      findings:
        - kind: defect
          id: BR-8
          severity: Critical
          title: Core concepts lists provider_scenarios as a PURE scenario table; the code is an IO driver and no scenario table exists
          detail: 'plan.md:66 and :79 describe a pure ProviderScenario table that the specs iterate, so adding a provider is one row. tests/helpers/provider_scenarios.lua spawns the fake, waits on uv, and mutates dispatcher.providers, logger and vault; it holds no table, and the scenarios are hand-written cases in provider_anthropic_spec.lua. Fix: a Revisions entry moving it to Integration points, and either build the data table before M2 or record per-dialect spec cases and align M2 Task 8 (ARCH-PURE, ARCH-DRY).'
          family: core-concepts-table-drift
          round: 3
        - kind: defect
          id: BR-9
          severity: Minor
          title: out_reader's reader state is two independent booleans, and the only test of the fix depends on write timing
          detail: dispatcher.lua:531-532 tracks stdout_finished and threw separately (a tagged reading/threw/finished state would do). The regression test needs frames plus a 20 ms write delay to line up reads; a deterministic dispatcher_query_spec case (a line with a throwing handler, then EOF (nil,nil), expecting one handler call) would pin it without timing (ARCH-ORDER).
          family: reader-state-flags
          round: 3
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 0c105810-ed61-4eb9-846b-00134cb14708
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1d34eb75364e6675
            reviewed_head: 54aad52d508e15795c80c98dd1087af24049a056
            slot: parley.nvim:4
            requested_at: "2026-10-16T16:50:49.525292Z"
          phase: finished
          pid: 44316
          started_at: "2026-10-16T16:50:49.949954Z"
          finished_at: "2026-10-16T16:53:46.064219Z"
          session_id: cf903fdd-11ca-40b7-91a2-85c9a62ad556
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 54aad52d508e15795c80c98dd1087af24049a056
        tracker_head: 42373d34413f9e3f3c5cb5bf922c919303c7c969
        branch_point: 76f1d090df46997ef8df56041640248d86383872
        since: "2026-10-16T07:13:14-07:00"
        until: "2026-10-16T09:49:08-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T07:13:14-07:00"
              end: "2026-10-16T09:49:08-07:00"
              began: "2026-10-16T07:13:14-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 202f437be48178d8c8dfd8067835d17229ded43331aff7aebc62f9d2b61190b0
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 15074164
              windows:
                - start: "2026-10-16T07:13:14-07:00"
                  end: "2026-10-16T09:49:08-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T07:40:48-07:00"
              finalized: "2026-10-16T07:43:38-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-16T08:00:02-07:00"
              finalized: "2026-10-16T08:02:56-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-16T09:53:47-07:00"
      dispatched: "2026-10-16T09:50:49-07:00"
      agent: claude
      dispose:
        - id: BR-8
          disposition: addressed
          note: provider_scenario_table.lua holds ROWS/PROFILES/rows_for/mismatches (pure, unit-tested in provider_scenario_table_spec); provider_scenarios_spec iterates profiles x rows; plan Core concepts moves provider_scenarios to Integration points and Task 8 adds profiles. 15/15 integration cases pass.
          round: 4
        - id: BR-9
          disposition: addressed
          note: 'dispatcher.lua uses a single tagged reader_state; A6-A8 are timing-free. Reverted in checkout: full revert fails A6+A8, dropping threw guard fails A7+A8, old ordering fails A6+A8.'
          round: 4
      findings:
        - kind: defect
          id: BR-10
          severity: Minor
          title: After a reader throws, EOF no longer runs finish_stdout, so usage/stop_reason/cache metrics go unrecorded
          detail: 'dispatcher.lua:645-648: the threw branch consumes EOF (nil,nil) and skips finish_stdout, which the base tree ran. The failure path does not read these fields today, but no test or atlas text states it. Either document it or call finish_stdout from the threw branch when chunk is nil.'
          family: undocumented-behavior-change
          round: 4
        - kind: defect
          id: BR-11
          severity: Minor
          title: Plan Task 3 Files list still names provider_anthropic_spec.lua and a drive() in provider_scenarios.lua
          detail: plan.md:142-143 contradicts the round-2 Revisions entry. Strike through those bullets the way Task 8's list was struck, pointing to the revision.
          family: plan-text-stale-after-revision
          round: 4
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      reviewed: 54aad52d508e15795c80c98dd1087af24049a056
      blocked: false
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

## Round 3 — 2026-10-16T08:02:56-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — run_proofs.sh:764-767 uses cap_empty/inband_error_empty and checks the notice text on each tree; ran it, 6/6 ok.
- BR-2 — addressed — tests/unit/fake_provider_spec.lua delivers the behaviour table, split invariant, check_mode, a curl per mode and request-log gating; 10/10 pass.
- BR-3 — addressed — S3 now asserts the warning containing "in-band — Overloaded" (provider_anthropic_spec.lua:578); the issue Log is struck through, but plan.md:226 still carries the retracted claim (see plan revisions).
- BR-4 — addressed — provider_anthropic_spec.lua:649 asserts equals("Hello,", out.qt.response); passes.
- BR-5 — addressed — S6 asserts raw_at_first_chunk < the total raw bytes (:612); the vocabulary needle is now '"stop_reason":"end_turn"'.
- BR-6 — addressed — check_mode/check_split are argparse types (fake_provider:121-122); fake_provider_spec.lua:890 asserts exit 2 for a typo.
- BR-7 — addressed — The frames split (sse_dialects.py:368), S4 for 429/529/500 (:581) and the no_stop integration case (:636) are delivered and pass.

### Raised

- **BR-8** [Critical] `core-concepts-table-drift` (kind: defect) Core concepts lists provider_scenarios as a PURE scenario table; the code is an IO driver and no scenario table exists
  plan.md:66 and :79 describe a pure ProviderScenario table that the specs iterate, so adding a provider is one row. tests/helpers/provider_scenarios.lua spawns the fake, waits on uv, and mutates dispatcher.providers, logger and vault; it holds no table, and the scenarios are hand-written cases in provider_anthropic_spec.lua. Fix: a Revisions entry moving it to Integration points, and either build the data table before M2 or record per-dialect spec cases and align M2 Task 8 (ARCH-PURE, ARCH-DRY).
- **BR-9** [Minor] `reader-state-flags` (kind: defect) out_reader's reader state is two independent booleans, and the only test of the fix depends on write timing
  dispatcher.lua:531-532 tracks stdout_finished and threw separately (a tagged reading/threw/finished state would do). The regression test needs frames plus a 20 ms write delay to line up reads; a deterministic dispatcher_query_spec case (a line with a throwing handler, then EOF (nil,nil), expecting one handler call) would pin it without timing (ARCH-ORDER).

## Round 4 — 2026-10-16T09:53:47-07:00 (claude) — passed

### Disposed

- BR-8 — addressed — provider_scenario_table.lua holds ROWS/PROFILES/rows_for/mismatches (pure, unit-tested in provider_scenario_table_spec); provider_scenarios_spec iterates profiles x rows; plan Core concepts moves provider_scenarios to Integration points and Task 8 adds profiles. 15/15 integration cases pass.
- BR-9 — addressed — dispatcher.lua uses a single tagged reader_state; A6-A8 are timing-free. Reverted in checkout: full revert fails A6+A8, dropping threw guard fails A7+A8, old ordering fails A6+A8.

### Raised

- **BR-10** [Minor] `undocumented-behavior-change` (kind: defect) After a reader throws, EOF no longer runs finish_stdout, so usage/stop_reason/cache metrics go unrecorded
  dispatcher.lua:645-648: the threw branch consumes EOF (nil,nil) and skips finish_stdout, which the base tree ran. The failure path does not read these fields today, but no test or atlas text states it. Either document it or call finish_stdout from the threw branch when chunk is nil.
- **BR-11** [Minor] `plan-text-stale-after-revision` (kind: defect) Plan Task 3 Files list still names provider_anthropic_spec.lua and a drive() in provider_scenarios.lua
  plan.md:142-143 contradicts the round-2 Revisions entry. Strike through those bullets the way Task 8's list was struck, pointing to the revision.

## Open findings

- **BR-10** [Minor] `undocumented-behavior-change` (kind: defect) After a reader throws, EOF no longer runs finish_stdout, so usage/stop_reason/cache metrics go unrecorded
- **BR-11** [Minor] `plan-text-stale-after-revision` (kind: defect) Plan Task 3 Files list still names provider_anthropic_spec.lua and a drive() in provider_scenarios.lua
