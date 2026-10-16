---
reviewer_runs:
    - version: 1
      intent:
        id: c2334449-748f-4814-b1db-988d991e2f6f
        repository: github.com/xianxu/parley.nvim
        issue_id: "000242"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: claude
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        reviewed_head: e729d98dd0d9cf72769a1e65c3456649ae9d5ae0
        slot: parley.nvim:4
        requested_at: "2026-10-16T14:25:46.166343Z"
      phase: finished
      pid: 14087
      started_at: "2026-10-16T14:25:46.317638Z"
      finished_at: "2026-10-16T14:26:08.156201Z"
      session_id: 190ede14-2200-42bf-8e44-09b6d30dd3d8
      outcome: returned
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
    - reviewer_runs:
        - version: 1
          intent:
            id: c475ddc7-2254-4ffb-ab05-33cf1f5c20b2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000242"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            reviewed_head: e729d98dd0d9cf72769a1e65c3456649ae9d5ae0
            slot: parley.nvim:4
            requested_at: "2026-10-16T14:25:28.505252Z"
          phase: finished
          pid: 12926
          started_at: "2026-10-16T14:25:28.659565Z"
          finished_at: "2026-10-16T14:25:44.573639Z"
          session_id: da3ae3ed-3a04-4747-867f-70d2d30ccc45
          outcome: returned
      "n": 3
      timestamp: "2026-10-16T07:25:44-07:00"
      agent: claude
      dispose:
        - id: PQ-8
          disposition: not-addressed
          note: 'Still open. dispatcher.lua:856-865 routes a cap (and the in-band-error ending) through _ending_notice to a logger line and then legacy_complete, never the error callback. The PQ-1 revision still expects a failure on the branch for max_tokens. Fix by rule: each proof case names the observable both trees expose and checks it on the branch first. Minor, carried to the close review.'
          round: 3
      blocked: false
content_hash: 01a731fcc13d47bfb98b7643df3f99740dd2c51e80b98f9edfa04a368d76d465
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

## Round 3 — 2026-10-16T07:25:44-07:00 (claude) — passed

### Disposed

- PQ-8 — not-addressed — Still open. dispatcher.lua:856-865 routes a cap (and the in-band-error ending) through _ending_notice to a logger line and then legacy_complete, never the error callback. The PQ-1 revision still expects a failure on the branch for max_tokens. Fix by rule: each proof case names the observable both trees expose and checks it on the branch first. Minor, carried to the close review.

## Open findings

- **PQ-8** [Minor] `regression-proof-runs-on-old-tree` (kind: defect) The 228 proof expects a max_tokens stream to fail on the branch, but the branch classifies a cap as a notice, which may not reach the failure callback
