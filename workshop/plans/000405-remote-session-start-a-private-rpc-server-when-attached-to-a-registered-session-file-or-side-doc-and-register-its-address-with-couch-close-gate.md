---
gate: boundary-review
issue: 405
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e58c4109-abfb-4384-a4ca-9adedec205f0
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81
            reviewed_head: 2b4916d7d41bf19cfcc4774381096c5fe6460041
            slot: parley.nvim:1
            requested_at: "2026-10-22T13:06:25.711744Z"
          phase: finished
          pid: 38707
          started_at: "2026-10-22T13:06:25.954374Z"
          finished_at: "2026-10-22T13:12:15.940146Z"
          session_id: 01a163b8-51df-7480-bf15-578e3861a2f4
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2b4916d7d41bf19cfcc4774381096c5fe6460041
        tracker_head: b9961037fb25a8284367753fad98e96f1afbfc5c
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T06:05:12-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T06:05:12-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 7c3da1afe165ac7978ed404cd7035021e14c245f8ceda8dbeb53b30739c61774
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 93503659
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 540c57ca85b25e91543b7bab51646020b935d0a9f5a54e8cb4391ee8da72398a
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 1043929
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a16386-b503-73f3-934d-1c36ecd543ba
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 864c95f43326d6cfa30962fc82d3c7840342543291376c403dbd0783e9b89f76
              started: "2026-10-22T12:12:15.322Z"
              spawned: false
              bytes: 616149
              windows:
                - start: "2026-10-22T12:12:15.322Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 534340d99d4ff0bc9c8ad41342fbb50568e89f9372d668f867f6fc280f779175
              started: "2026-10-22T12:16:27.346Z"
              spawned: false
              bytes: 465654
              windows:
                - start: "2026-10-22T12:16:27.346Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a1638c-6e36-7142-94d2-59f91265ff08
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 06189877b85000f3bbf7e024dc87c8eba47ac797591173d925a806ec13051cb4
              started: "2026-10-22T12:18:30.499Z"
              spawned: false
              bytes: 471863
              windows:
                - start: "2026-10-22T12:18:30.499Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a1638c-e3cf-7b91-a5c2-fb326f3ae063
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 7fe16589d51c8c31b02ecbf061c1615352b117f78a66687145005ee7b65d939d
              started: "2026-10-22T12:19:00.509Z"
              spawned: false
              bytes: 434932
              windows:
                - start: "2026-10-22T12:19:00.509Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9c91250065a4db55b139d83b5330d384298082cb76cdc0217dab83d55ceb3b36
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 1360640
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T06:05:12-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 4aaec37acc708013512cc47941aed0e6becbbc4c68c1c47169e98f46cd9598bb
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 1974954
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T06:05:12-07:00"
      "n": 1
      timestamp: "2026-10-22T06:12:16-07:00"
      dispatched: "2026-10-22T06:06:25-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Detach leaves queued publication and orphaned startup work running
          detail: lua/parley/remote_session.lua:91 discards the registry request handle, and detach at line 213 neither cancels queued publication nor cancels startup when its final consumer retires. This contradicts the plan's detach/cancellation contract at lines 80 and 94 (ARCH-ORDER, ARCH-PURPOSE). A native probe occupied all four transport slots, queued an attachment, detached it, and observed one register child start afterward. Retain request handles, cancel unstarted publication, and cancel/join startup when no attachments still need it; preserve exact cleanup for already-admitted effects.
          family: retirement-cancels-unstarted-effects
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: First-listener startup resets the promised absolute deadline
          detail: lua/parley/remote_runtime.lua:307 gives acquire its own 2000ms transaction, while listen at line 203 starts another independent 2000ms transaction. No deadline passes between them, contrary to the plan's entire-first-listener 2000ms budget at line 94 (ARCH-CONSTRAINTS). A controlled native probe with an 800ms process-source delay and 1500ms asynchronous fsync delay successfully returned listening after 2339ms. Carry one absolute deadline through acquisition and first-listener publication, rejecting new effects after it expires.
          family: aggregate-operation-deadline
          round: 1
        - kind: defect
          id: BR-3
          severity: Critical
          title: The Core concepts table points RuntimeOwnershipRecord at the wrong module
          detail: workshop/plans/000405-remote-session-endpoint-plan.md:22 declares RuntimeOwnershipRecord in remote_session_model.lua, but its codec and cleanup decision exist in lua/parley/remote_runtime_record.lua. The later revision acknowledges this split without correcting the authoritative table. This is the Core concepts contradiction classified Critical by this review contract (ARCH-PURE). Correct the table and add the runtime ownership shell to the integration inventory; retain the accurate PURE classification for the computational codec.
          family: core-concept-location-consistency
          round: 1
        - kind: defect
          id: BR-4
          severity: Important
          title: Detaching the final attachment retains an unused runtime directory
          detail: lua/parley/remote_session.lua:109 permits runtime cleanup only after global close sets closing=true. Ordinary final detach therefore removes the socket but retains owner.json and the process directory, contrary to the plan's last-close cleanup rule at line 92 (ARCH-FUNERAL). A native probe confirmed the directory remained after its socket list became empty. Close the unused runtime after pending cleanup drains, safely coordinating a concurrent new attachment, and test final detach without calling frontend.close.
          family: last-consumer-resource-release
          round: 1
        - kind: defect
          id: BR-5
          severity: Important
          title: README omits the new endpoint-conformance flag
          detail: scripts/check-couch-registry-conformance.py:129 introduces the runnable --editor-endpoints flag, but README.md is unchanged in the pinned range. The explicit README update gate therefore remains unmet. Document the invocation, including --fake-only usage and the deferred real-producer prerequisites; no wording-presence test is needed.
          family: readme-runnable-surface-documentation
          round: 1
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#405 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T06:12:16-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `retirement-cancels-unstarted-effects` (kind: defect) Detach leaves queued publication and orphaned startup work running
  lua/parley/remote_session.lua:91 discards the registry request handle, and detach at line 213 neither cancels queued publication nor cancels startup when its final consumer retires. This contradicts the plan's detach/cancellation contract at lines 80 and 94 (ARCH-ORDER, ARCH-PURPOSE). A native probe occupied all four transport slots, queued an attachment, detached it, and observed one register child start afterward. Retain request handles, cancel unstarted publication, and cancel/join startup when no attachments still need it; preserve exact cleanup for already-admitted effects.
- **BR-2** [Critical] `aggregate-operation-deadline` (kind: defect) First-listener startup resets the promised absolute deadline
  lua/parley/remote_runtime.lua:307 gives acquire its own 2000ms transaction, while listen at line 203 starts another independent 2000ms transaction. No deadline passes between them, contrary to the plan's entire-first-listener 2000ms budget at line 94 (ARCH-CONSTRAINTS). A controlled native probe with an 800ms process-source delay and 1500ms asynchronous fsync delay successfully returned listening after 2339ms. Carry one absolute deadline through acquisition and first-listener publication, rejecting new effects after it expires.
- **BR-3** [Critical] `core-concept-location-consistency` (kind: defect) The Core concepts table points RuntimeOwnershipRecord at the wrong module
  workshop/plans/000405-remote-session-endpoint-plan.md:22 declares RuntimeOwnershipRecord in remote_session_model.lua, but its codec and cleanup decision exist in lua/parley/remote_runtime_record.lua. The later revision acknowledges this split without correcting the authoritative table. This is the Core concepts contradiction classified Critical by this review contract (ARCH-PURE). Correct the table and add the runtime ownership shell to the integration inventory; retain the accurate PURE classification for the computational codec.
- **BR-4** [Important] `last-consumer-resource-release` (kind: defect) Detaching the final attachment retains an unused runtime directory
  lua/parley/remote_session.lua:109 permits runtime cleanup only after global close sets closing=true. Ordinary final detach therefore removes the socket but retains owner.json and the process directory, contrary to the plan's last-close cleanup rule at line 92 (ARCH-FUNERAL). A native probe confirmed the directory remained after its socket list became empty. Close the unused runtime after pending cleanup drains, safely coordinating a concurrent new attachment, and test final detach without calling frontend.close.
- **BR-5** [Important] `readme-runnable-surface-documentation` (kind: defect) README omits the new endpoint-conformance flag
  scripts/check-couch-registry-conformance.py:129 introduces the runnable --editor-endpoints flag, but README.md is unchanged in the pinned range. The explicit README update gate therefore remains unmet. Document the invocation, including --fake-only usage and the deferred real-producer prerequisites; no wording-presence test is needed.

## Open findings

- **BR-1** [Critical] `retirement-cancels-unstarted-effects` (kind: defect) Detach leaves queued publication and orphaned startup work running
- **BR-2** [Critical] `aggregate-operation-deadline` (kind: defect) First-listener startup resets the promised absolute deadline
- **BR-3** [Critical] `core-concept-location-consistency` (kind: defect) The Core concepts table points RuntimeOwnershipRecord at the wrong module
- **BR-4** [Important] `last-consumer-resource-release` (kind: defect) Detaching the final attachment retains an unused runtime directory
- **BR-5** [Important] `readme-runnable-surface-documentation` (kind: defect) README omits the new endpoint-conformance flag
