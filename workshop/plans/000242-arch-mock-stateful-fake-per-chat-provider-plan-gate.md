---
gate: plan-quality
issue: 242
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: d8c56d14-9e82-4026-bc32-2783d4313b3f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            reviewed_head: c73924f6d6ad955d53c3580753cf7a4c79c059d6
            slot: parley.nvim:4
            requested_at: "2026-10-16T14:21:04.371059Z"
          phase: finished
          pid: 96965
          started_at: "2026-10-16T14:21:04.512114Z"
          finished_at: "2026-10-16T14:22:07.036919Z"
          session_id: ed0c6505-9df1-4edf-a827-97a7b202865f
          outcome: returned
      "n": 1
      timestamp: "2026-10-16T07:22:07-07:00"
      agent: claude
      findings:
        - kind: defect
          id: PQ-1
          severity: Important
          title: '#228/#229 regression proofs do not say how the new fake and specs run on pre-fix trees, so they can fail for the wrong reason'
          detail: At dc548920^, tests/fixtures/loopback_http.py is missing and _classify_ending/_ending_notice do not exist yet (31 dispatcher/tasker commits since then). The plan must name which files get copied onto the scratch worktree, use an assertion that works on both trees (success reported instead of failure, not the new notice text), and check that the old-tree run reached that assertion.
          family: regression-proof-runs-on-old-tree
          round: 1
        - kind: defect
          id: PQ-2
          severity: Important
          title: 'S7 (disconnect after N bytes) cannot make the reader throw, which is the #229 bug, and the plan forbids the seam needed to inject one'
          detail: 'A server disconnect ends curl early; it does not make out_reader throw. Name the seam or real trigger for the throwing reader (e.g. pending session invalidated mid-stream), or split S7 into disconnect handling plus a separate #229 case.'
          family: scenario-cannot-trigger-named-bug
          round: 1
        - kind: defect
          id: PQ-3
          severity: Minor
          title: The issue's Spec 3 and Done-when still say HTTP error with retry and six scenarios; record the approved decisions as a Revisions entry
          family: plan-revision-not-recorded
          round: 1
        - kind: defect
          id: PQ-4
          severity: Minor
          title: The PARLEY_FAKE_REQUEST_LOG file has no stated owner or removal path (ARCH-FUNERAL)
          family: artifact-removal-path
          round: 1
        - kind: defect
          id: PQ-5
          severity: Minor
          title: The copilot token-URL seam redirects a request carrying the GitHub token; state dummy secrets plus reset in after_each, and keep keys out of live-spec failure messages (ARCH-SECURE)
          family: credential-reach-in-tests
          round: 1
        - kind: defect
          id: PQ-6
          severity: Minor
          title: Task 2 lists test cases in prose; compress to one strategy line per risky function (BehaviorModel, FrameSplitter)
          family: test-plan-enumeration
          round: 1
        - kind: defect
          id: PQ-7
          severity: Minor
          title: S6 splits every byte with a flush each time but states no fixture-size or spec-runtime cap (ARCH-CONSTRAINTS)
          family: operating-envelope-unstated
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: dd75280f-c3ef-4318-9e4a-335ddb117784
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            reviewed_head: 940fdd7dd4b349418addcc1c99ceada303cc64a6
            slot: parley.nvim:4
            requested_at: "2026-10-16T14:23:13.044329Z"
          phase: finished
          pid: 6919
          started_at: "2026-10-16T14:23:13.231391Z"
          finished_at: "2026-10-16T14:23:55.042207Z"
          session_id: 268a96bc-744e-4306-b71c-8f62eaccd047
          outcome: returned
      "n": 2
      timestamp: "2026-10-16T07:23:55-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Standalone proof scripts run from a pre-fix worktree, start the branch's fake by absolute path, assert behaviour, and guard on a PROOF-REACHED marker.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: S7b throws from the dispatcher.query handler, which out_reader calls unprotected (dispatcher.lua:566), so the throw reaches tasker read/call_safely, the code 634e33a9 changed.
          round: 2
        - id: PQ-3
          disposition: addressed
          round: 2
        - id: PQ-4
          disposition: addressed
          round: 2
        - id: PQ-5
          disposition: addressed
          round: 2
        - id: PQ-6
          disposition: addressed
          round: 2
        - id: PQ-7
          disposition: addressed
          round: 2
      findings:
        - kind: defect
          id: PQ-8
          severity: Minor
          title: The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
          detail: '2nd finding in this family. Rule: each proof names, per case, the observable both trees expose (which callback fires and with what argument), and checks it on the branch before reading the old tree''s result. _ending_notice treats class cap as advisory text, so the cap case may need to assert the notice or the stop_reason path rather than the error callback.'
          family: regression-proof-runs-on-old-tree
          round: 2
      blocked: false
content_hash: dbc6ddb0f709ca83d6bd33ae83283d6b6b4a2a83d0cf39397717917ce5d6e96e
---

# Gate ledger — parley.nvim#242 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T07:22:07-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `regression-proof-runs-on-old-tree` (kind: defect) #228/#229 regression proofs do not say how the new fake and specs run on pre-fix trees, so they can fail for the wrong reason
  At dc548920^, tests/fixtures/loopback_http.py is missing and _classify_ending/_ending_notice do not exist yet (31 dispatcher/tasker commits since then). The plan must name which files get copied onto the scratch worktree, use an assertion that works on both trees (success reported instead of failure, not the new notice text), and check that the old-tree run reached that assertion.
- **PQ-2** [Important] `scenario-cannot-trigger-named-bug` (kind: defect) S7 (disconnect after N bytes) cannot make the reader throw, which is the #229 bug, and the plan forbids the seam needed to inject one
  A server disconnect ends curl early; it does not make out_reader throw. Name the seam or real trigger for the throwing reader (e.g. pending session invalidated mid-stream), or split S7 into disconnect handling plus a separate #229 case.
- **PQ-3** [Minor] `plan-revision-not-recorded` (kind: defect) The issue's Spec 3 and Done-when still say HTTP error with retry and six scenarios; record the approved decisions as a Revisions entry
- **PQ-4** [Minor] `artifact-removal-path` (kind: defect) The PARLEY_FAKE_REQUEST_LOG file has no stated owner or removal path (ARCH-FUNERAL)
- **PQ-5** [Minor] `credential-reach-in-tests` (kind: defect) The copilot token-URL seam redirects a request carrying the GitHub token; state dummy secrets plus reset in after_each, and keep keys out of live-spec failure messages (ARCH-SECURE)
- **PQ-6** [Minor] `test-plan-enumeration` (kind: defect) Task 2 lists test cases in prose; compress to one strategy line per risky function (BehaviorModel, FrameSplitter)
- **PQ-7** [Minor] `operating-envelope-unstated` (kind: defect) S6 splits every byte with a flush each time but states no fixture-size or spec-runtime cap (ARCH-CONSTRAINTS)

## Round 2 — 2026-10-16T07:23:55-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Standalone proof scripts run from a pre-fix worktree, start the branch's fake by absolute path, assert behaviour, and guard on a PROOF-REACHED marker.
- PQ-2 — addressed — S7b throws from the dispatcher.query handler, which out_reader calls unprotected (dispatcher.lua:566), so the throw reaches tasker read/call_safely, the code 634e33a9 changed.
- PQ-3 — addressed
- PQ-4 — addressed
- PQ-5 — addressed
- PQ-6 — addressed
- PQ-7 — addressed

### Raised

- **PQ-8** [Minor] `regression-proof-runs-on-old-tree` (kind: defect) The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
  2nd finding in this family. Rule: each proof names, per case, the observable both trees expose (which callback fires and with what argument), and checks it on the branch before reading the old tree's result. _ending_notice treats class cap as advisory text, so the cap case may need to assert the notice or the stop_reason path rather than the error callback.

## Open findings

- **PQ-8** [Minor] `regression-proof-runs-on-old-tree` (kind: defect) The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
