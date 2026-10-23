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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 3015590d-e175-4372-a526-3b622c7b7450
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/ddfef1796eb77f5c
            reviewed_head: a735c729fd37c90f6ef828eecaecad85286cbd31
            slot: parley.nvim:1
            requested_at: "2026-10-22T13:30:25.684184Z"
          phase: finished
          pid: 94209
          started_at: "2026-10-22T13:30:25.859369Z"
          finished_at: "2026-10-22T13:35:02.894578Z"
          session_id: 01a163ce-4b5f-7412-87ed-b730abb4194b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: a735c729fd37c90f6ef828eecaecad85286cbd31
        tracker_head: 79c32d5649a5ce72708aa78b7a35c97fbfa0d229
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T06:28:32-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T06:28:32-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: af8739790e380590b563f68d8e939edc89cdc7d0ae86fab7fef98bf36c1101ba
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 94455059
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T06:28:32-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 98c7006f14fe7e850e6d85f52a5416008e21997c3338c00e8822705731cbedc0
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 1519256
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T06:28:32-07:00"
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
                  end: "2026-10-22T06:28:32-07:00"
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
                  end: "2026-10-22T06:28:32-07:00"
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
                  end: "2026-10-22T06:28:32-07:00"
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
                  end: "2026-10-22T06:28:32-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: dd0625cab12f9b170e3c1303168d07c7c633ec4e4fce1f8390dc1a607824e65f
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 1687063
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T06:28:32-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 06b692efde1bc0a1cb2e6cd9fc1c0454bc1068a507db642718f05811558ba1fe
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 2292492
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T06:28:32-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T06:35:03-07:00"
      dispatched: "2026-10-22T06:30:25-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'Queued publication and acquisition cancellation are fixed, with regressions that fail against the previous dispatcher. However, remote_session.lua:229 discards runtime.listen''s operation handle; release_consumer at lines 36–44 cancels only acquisition, whose handle is cleared at line 92. A controlled native probe held first-listener reservation fsync, detached the final consumer, then released completion: cancellation calls were 0 and serverstart calls after detach were 1. Retain and cancel/join listener startup operations too, prevent subsequent startup effects after retirement, and add controlled reservation/publication cancellation tests. This remains the existing retirement-cancels-unstarted-effects family finding (ARCH-ORDER, ARCH-PURPOSE).'
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'remote_runtime.lua carries the acquisition deadline into first-listener publication and clears it only after durable success. Both reservation and publication regressions pass at head and fail with the previous runtime loaded: 22 passed, 2 failed, 0 errors.'
          round: 2
        - id: BR-3
          disposition: addressed
          note: The plan's authoritative table now locates RuntimeOwnershipRecord in remote_runtime_record.lua:22, matching its computational codec and cleanup decision. The integration inventory at line 34 also names remote_runtime.lua's ownership shell. Both PURE entities have direct tests without IO dependencies.
          round: 2
        - id: BR-4
          disposition: addressed
          note: Final consumer drain now closes the exact runtime without global frontend.close. The ordinary-detach regression at remote_session_spec.lua:426 passes at head and fails against the previous dispatcher; terminal-resource and attach-during-drain regressions also fail against that dispatcher.
          round: 2
        - id: BR-5
          disposition: addressed
          note: README.md:208–213 documents --editor-endpoints --fake-only and the deferred producer/bridge prerequisites. This matches the script's options and the exercised fake/native probe, including its corrupt-reply negative control.
          round: 2
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 60178087-20d6-466e-8544-644f1b2bc26a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/bf660ed24e2a3884
            reviewed_head: 1b91aadf4c99449d99397c3a7a0cecc46ccd61c6
            slot: parley.nvim:1
            requested_at: "2026-10-22T14:04:21.316156Z"
          phase: finished
          pid: 38139
          started_at: "2026-10-22T14:04:21.488193Z"
          finished_at: "2026-10-22T14:09:18.857247Z"
          session_id: 01a163ed-5ac1-7c11-a18c-c6bd35b84cd8
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1b91aadf4c99449d99397c3a7a0cecc46ccd61c6
        tracker_head: 79c32d5649a5ce72708aa78b7a35c97fbfa0d229
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T07:03:07-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T07:03:07-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: bedc85be260e16d3b07bf12c46b0b1d5d09bd49a6685d7a97571e3e293f8a18d
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 96481516
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T07:03:07-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 41cd0e1ba81545f977b83d50312815d68a993ffa30b62b3ba74f071013740274
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 1637213
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T07:03:07-07:00"
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
                  end: "2026-10-22T07:03:07-07:00"
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
                  end: "2026-10-22T07:03:07-07:00"
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
                  end: "2026-10-22T07:03:07-07:00"
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
                  end: "2026-10-22T07:03:07-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 3a818df32a4befddb2a66f8c849502596b79203452479b3887fda7d29a4b3788
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 2162960
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T07:03:07-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 54bf9f72c6d9901ca7404259d3d1249b5fabb6d8628eb1f894afb7e7358fbcd4
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 2808447
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T07:03:07-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T06:30:25-07:00"
              finalized: "2026-10-22T06:35:03-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-22T07:09:19-07:00"
      dispatched: "2026-10-22T07:04:21-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Exact listener handles are retained and canceled at remote_session.lua:43. Removing that call produced five dispatcher failures; reverting runtime finalization produced nine runtime failures. Pinned-head tests pass, including live-keeper continuity, reservation cleanup and slot reuse.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Acquisition carries ctx.deadline into resource.startup_deadline and the first listener transaction. Reservation/publication deadline regressions pass on both supported runtimes.
          round: 3
        - id: BR-3
          disposition: addressed
          note: The pinned before/after diff corrects the Core concepts passage to RuntimeOwnershipRecord at lua/parley/remote_runtime_record.lua; that module implements the pure codec and cleanup decision.
          round: 3
        - id: BR-4
          disposition: addressed
          note: Last-consumer draining reaches exact runtime close. The regression at remote_session_spec.lua:422 verifies removal of the final socket, marker and directory without closing the editor.
          round: 3
        - id: BR-5
          disposition: addressed
          note: README.md:208 documents --editor-endpoints --fake-only and the real-producer prerequisites. The documented command passes and rejects its deliberately corrupted reply.
          round: 3
      findings:
        - kind: defect
          id: BR-6
          severity: Important
          title: A rejected canonical-file acknowledgment is still reported as confirmed
          detail: At lua/parley/remote_session.lua:131-135, dispatch can reject a binding whose File differs from the attachment identity, yet the shell checks and reports the original confirmed result. remote_session_model.lua:285 also stores that rejected result unchanged. A disposable native probe returning File=/different-document.md observed callback=confirmed and phase=unconfirmed, without an unavailable notice. Normalize rejected confirmations through the model’s accepted outcome, use that outcome for callbacks and notices, and add a dispatcher regression. ARCH-SECURE, ARCH-ORDER.
          family: validated-authority-outcomes
          round: 3
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 72d1245b-ab98-424b-b7ea-7faf5f1f8a8c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/fdff89dc44fd75be
            reviewed_head: 3ae643672ab1a24d763cd40141533899ec980d07
            slot: parley.nvim:1
            requested_at: "2026-10-22T14:19:27.681127Z"
          phase: finished
          pid: 4997
          started_at: "2026-10-22T14:19:27.784398Z"
          finished_at: "2026-10-22T14:26:17.934885Z"
          session_id: 01a163fb-2db7-7de0-a101-866e044d9e3b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3ae643672ab1a24d763cd40141533899ec980d07
        tracker_head: 79c32d5649a5ce72708aa78b7a35c97fbfa0d229
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T07:18:31-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T07:18:31-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 83d5f0793e31a5eab1372b53b0fa9c8672466908c3a1f299dc9d644b7995912e
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 97152456
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T07:18:31-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9d626a12d4cc6f5e0f10bd5314bb67bbfec39efc88c1a95914d33b71e436f5d0
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 1742856
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T07:18:31-07:00"
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
                  end: "2026-10-22T07:18:31-07:00"
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
                  end: "2026-10-22T07:18:31-07:00"
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
                  end: "2026-10-22T07:18:31-07:00"
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
                  end: "2026-10-22T07:18:31-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 66c885bbc81154f107a863ae8f1ffdbd7cd4c820a0ea32e3d314a17d5106b8a3
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 2358854
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T07:18:31-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 54bf9f72c6d9901ca7404259d3d1249b5fabb6d8628eb1f894afb7e7358fbcd4
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 2808447
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T07:18:31-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T06:30:25-07:00"
              finalized: "2026-10-22T06:35:03-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:04:21-07:00"
              finalized: "2026-10-22T07:09:19-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-22T07:26:19-07:00"
      dispatched: "2026-10-22T07:19:27-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Exact listener cancellation remains implemented; queued-publication, held-startup, reservation/publication cancellation, and slot-reuse regressions pass on both runtimes.
          round: 4
        - id: BR-2
          disposition: addressed
          note: Acquisition passes its absolute deadline into first-listener publication; reservation and publication deadline regressions pass on both runtimes.
          round: 4
        - id: BR-3
          disposition: addressed
          note: The Core concepts table names lua/parley/remote_runtime_record.lua, whose implementation contains the pure ownership codec and cleanup decision.
          round: 4
        - id: BR-4
          disposition: addressed
          note: remote_session_spec.lua:462 verifies final detach removes the listener, marker, and directory without closing the editor; it passes on both runtimes.
          round: 4
        - id: BR-5
          disposition: addressed
          note: README.md:208 documents --editor-endpoints --fake-only and the deferred real prerequisites; the documented command passes its positive and corrupt-reply controls.
          round: 4
        - id: BR-6
          disposition: addressed
          note: Model normalization and shell consumption of snapshot().result are reachable. Removing the correction produces 12 model failures and one dispatcher failure; pinned-head regressions pass.
          round: 4
      findings:
        - kind: defect
          id: BR-7
          severity: Critical
          title: Unsupported attachment paths throw after listener creation and wedge the dispatcher
          detail: lua/parley/remote_session.lua:197-200 validates Namespace and DocumentID but not File against the complete attachment-context contract. A real canonical filename containing a newline passes preflight, starts a listener, then throws at model.new on line 238 because remote_session_model.lua:47 rejects that spelling. The exception skips done(listening) at line 254, leaving io_busy set. Native probes on 0.12.5 and 0.11.7 observed invalid attachment context, no attachment callback, and no subsequent ordinary-attachment or close callback. Validate the complete context through shared pure validation before allocating resources, handle rejected construction through normal cleanup/completion, and add a sequence regression proving a rejected attachment cannot block later attachment or close. ARCH-SECURE, ARCH-ORDER.
          family: validate-before-resource-allocation
          round: 4
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ed381057-522d-43f9-bd65-00fac7aabb7b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 5
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/399bef0f1bce698b
            reviewed_head: 411be8ebf62e2b04ba101cd14225e04f13300a03
            slot: parley.nvim:1
            requested_at: "2026-10-22T14:46:18.28294Z"
          phase: finished
          pid: 92898
          started_at: "2026-10-22T14:46:18.416208Z"
          finished_at: "2026-10-22T14:49:51.323465Z"
          session_id: 01a16413-c1c9-77a0-be00-bb25d4dd8827
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 411be8ebf62e2b04ba101cd14225e04f13300a03
        tracker_head: 79c32d5649a5ce72708aa78b7a35c97fbfa0d229
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T07:45:15-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T07:45:15-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: e18ae1a66a957b296afd39b97f331a9bb2e99bcd1b730fc2187025a32805af67
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 98407156
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T07:45:15-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9d626a12d4cc6f5e0f10bd5314bb67bbfec39efc88c1a95914d33b71e436f5d0
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 1742856
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T07:45:15-07:00"
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
                  end: "2026-10-22T07:45:15-07:00"
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
                  end: "2026-10-22T07:45:15-07:00"
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
                  end: "2026-10-22T07:45:15-07:00"
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
                  end: "2026-10-22T07:45:15-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6f4e4aa828080c9353b58118f4fc90e9a38b9c50d2cd6cb1d4281b8c374ca9df
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 2447917
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T07:45:15-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 3094cd538c9ebd76a6ab07200b8bd532eef0bd0709869f182585671d90e397a4
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 3151523
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T07:45:15-07:00"
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T06:30:25-07:00"
              finalized: "2026-10-22T06:35:03-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:04:21-07:00"
              finalized: "2026-10-22T07:09:19-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:19:27-07:00"
              finalized: "2026-10-22T07:26:19-07:00"
              finalizing: false
      "n": 5
      timestamp: "2026-10-22T07:49:52-07:00"
      dispatched: "2026-10-22T07:46:18-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Existing cancellation regressions pass, including held acquisition, queued registration, all four listener startup boundaries, cleanup joining and slot reuse.
          round: 5
        - id: BR-2
          disposition: addressed
          note: remote_runtime.lua carries startup_deadline through first-listener durability; reservation and publication deadline regressions pass on both runtimes.
          round: 5
        - id: BR-3
          disposition: addressed
          note: The plan's Pure entities table identifies remote_runtime_record.lua as RuntimeOwnershipRecord's location; that module implements the codec and cleanup decision.
          round: 5
        - id: BR-4
          disposition: addressed
          note: Last-consumer drain closes the runtime automatically; final-detach cleanup and attach-during-drain regressions pass on both runtimes.
          round: 5
        - id: BR-5
          disposition: addressed
          note: README.md documents --editor-endpoints --fake-only and the deferred real prerequisites; the parser implements that invocation and its fake conformance check passed.
          round: 5
        - id: BR-6
          disposition: addressed
          note: The model normalizes unowned confirmations before storing results, and the dispatcher consumes that accepted result. Mismatched-identity and canonical-file regressions pass.
          round: 5
        - id: BR-7
          disposition: addressed
          note: Shared validation precedes allocation and checks the allocated tuple; constructor refusal or exception follows cleanup/completion. Removing the production fix in a disposable checkout caused six pure failures and four native continuation failures, with zero test errors. Pinned-head tests pass.
          round: 5
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      reviewed: 411be8ebf62e2b04ba101cd14225e04f13300a03
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2bbf7b4d-ee55-4f16-a8f6-dbc99491c11a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/3bd173b7adfcdbd3
            reviewed_head: 6b35f51b1b61a3c440775c213b63876344b35562
            slot: parley.nvim:1
            requested_at: "2026-10-23T06:20:36.303908Z"
          phase: finished
          pid: 79298
          started_at: "2026-10-23T06:20:36.409341Z"
          finished_at: "2026-10-23T06:24:08.111983Z"
          session_id: 01a1676b-22bd-78b2-8df1-857f77225bbe
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 6b35f51b1b61a3c440775c213b63876344b35562
        tracker_head: 2e3552a346bc86175fbbf24ca966cfae85aac611
        branch_point: 69657dfa119c3b70cd27dccca42db5c088bdf255
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T23:19:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T23:19:53-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: a2cac09b91d847b2c00da5f5cdada17efb90331829ad31ed06751a3db5435e52
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 114756367
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 1726f861f9ce9080cfa0f957a9b25fc43cc9d3ff894ce378c1a63b24b9700dd3
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 2170263
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T23:19:53-07:00"
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
                  end: "2026-10-22T23:19:53-07:00"
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
                  end: "2026-10-22T23:19:53-07:00"
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
                  end: "2026-10-22T23:19:53-07:00"
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
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6e5921f3bd05652c6d20799a3ede34c9ed2df82423f23e6af78f6414bed1cbb3
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 3362403
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: e7da4fd101c759892f4e37a8bad101d185c91694d3877c103770c806ec735763
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 5348521
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a16581-c3a0-7d91-b8cc-7370e4f9a388
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: f08c4168c76c8cb7bd108b96cc68b0753a2f39223b0a74a99f30fd69c543e7dd
              started: "2026-10-22T21:26:05.787Z"
              spawned: true
              bytes: 689933
              windows:
                - start: "2026-10-22T21:26:05.787Z"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a16590-7404-7410-8786-e00f43757dc5
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: eaccbce52bbfaf6bb551627eadba9e277dfbdf1dc368286c979fbfa4983628df
              started: "2026-10-22T21:42:08.267Z"
              spawned: true
              bytes: 1023075
              windows:
                - start: "2026-10-22T21:42:08.267Z"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a16757-eeb8-7c22-81ed-8ca60a3ab76d
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5e50a4b95341a68615c93c12db1633fe796a70d1cdbdd3e500ef030eccd914e3
              started: "2026-10-23T05:59:38.525Z"
              spawned: true
              bytes: 454873
              windows:
                - start: "2026-10-23T05:59:38.525Z"
                  end: "2026-10-22T23:19:53-07:00"
            - harness: codex
              id: 01a1675d-65b8-7733-8d95-fed455d12d74
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: d9ec0847e5bcbda2efe1a8824f4156a2a1103445466ed1704596c4d2c2fd76f8
              started: "2026-10-23T06:05:36.68Z"
              spawned: true
              bytes: 626239
              windows:
                - start: "2026-10-23T06:05:36.68Z"
                  end: "2026-10-22T23:19:53-07:00"
        queue_waits:
            - attempt_id: 03b79fe303c4473bd688542de9302c6b
              slot: parley.nvim:1
              record_digest: 93fa8a766d93cac1e26d50e8571ff57a0be03d26b614d37134716e1a7935e6cd
              start: "2026-10-22T14:45:52.190947Z"
              end: "2026-10-22T16:04:57.90039Z"
              queue_seconds: 4745.709443
              raw_seconds: 4745.709443
              exact: true
            - attempt_id: 5e80962d43811d5f3a8a39098aa0037c
              slot: parley.nvim:1
              record_digest: 99d7a927271707e8a83f72df76c243c25ff3ee7a06476b2b100c63ea4ee6c3d4
              start: "2026-10-22T16:35:46.792367Z"
              end: "2026-10-22T18:49:44.703658Z"
              queue_seconds: 8037.911291
              raw_seconds: 8037.911291
              exact: true
            - attempt_id: f2bf5c7b2996847ab0a5adcedf83cdb0
              slot: parley.nvim:1
              record_digest: 1640c77c9f4488d9f7ce03e484d0e8d7e04dcabcd4f0472c2da3b0f6ce4d78d5
              start: "2026-10-22T22:45:11.470906Z"
              end: "2026-10-23T00:48:47.140357Z"
              queue_seconds: 7415.669451
              raw_seconds: 7415.669451
              exact: true
        protected:
            - issue: "413"
              slot: parley.nvim:1
              start: "2026-10-22T19:56:15.6Z"
              end: "2026-10-22T20:09:41.441Z"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-23T01:01:43.764Z"
              end: "2026-10-22T18:11:02-07:00"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-22T18:11:02-07:00"
              end: "2026-10-23T01:34:34.464Z"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-23T01:04:05.561Z"
              end: "2026-10-22T18:11:02-07:00"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-22T18:11:02-07:00"
              end: "2026-10-23T01:22:49.851Z"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 256.6123
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T06:30:25-07:00"
              finalized: "2026-10-22T06:35:03-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:04:21-07:00"
              finalized: "2026-10-22T07:09:19-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:19:27-07:00"
              finalized: "2026-10-22T07:26:19-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:46:18-07:00"
              finalized: "2026-10-22T07:49:52-07:00"
              finalizing: true
      "n": 6
      timestamp: "2026-10-22T23:24:09-07:00"
      dispatched: "2026-10-22T23:20:36-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-8
          severity: Important
          title: Report unavailable outside-pane discovery
          detail: 'lua/parley/remote_session.lua:370-374 handles only registered results and silently drops unavailable discovery, contradicting the plan''s promised remote-unavailable notice. A production-observe probe returning unavailable produced one lookup, zero notices and zero allocations; duplicate observe did not retry. ARCH-PURPOSE, ARCH-SECURE: distinguish positive absence from discovery failure, emit one bounded notice per buffer incarnation, and sweep discovery-to-attachment rejection paths. Add regressions covering timeout/malformed results, silent positive absence, and duplicate-event deduplication.'
          family: visible-remote-availability-failures
          round: 6
        - kind: defect
          id: BR-9
          severity: Important
          title: Document the required real-conformance bridge invocation in README
          detail: 'scripts/check-couch-registry-conformance.py:175-186 adds --bridge and requires it for real endpoint conformance, but README.md:213-218 still documents only fake-only execution and prerequisites; README is unchanged in this range. This is the 2nd finding in family readme-runnable-surface-documentation. Earlier rounds fixed instances. State and apply the rule across the changed runnable surface: every introduced or changed invocation must have usable README guidance. Document the real command, absolute bridge requirement and native Neovim selection; atlas/modes/remote_session.md already supplies the concrete referent. No wording-presence test is needed.'
          family: readme-runnable-surface-documentation
          round: 6
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 11a80245-be01-4d32-9847-77169cbb70f8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/2464fb7b496173d8
            reviewed_head: 4508683883564bbd676e42c2ee50d15935a95454
            slot: parley.nvim:1
            requested_at: "2026-10-23T06:42:06.410138Z"
          phase: finished
          pid: 34921
          started_at: "2026-10-23T06:42:06.514697Z"
          finished_at: "2026-10-23T06:46:35.846371Z"
          session_id: 01a1677e-d239-7001-a6e7-310fdca143d5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4508683883564bbd676e42c2ee50d15935a95454
        tracker_head: 2e3552a346bc86175fbbf24ca966cfae85aac611
        branch_point: 69657dfa119c3b70cd27dccca42db5c088bdf255
        since: "2026-10-22T04:55:52-07:00"
        until: "2026-10-22T23:41:28-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T04:55:52-07:00"
              end: "2026-10-22T23:41:28-07:00"
              began: "2026-10-22T04:55:52-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 6ecb793e4959dff1f78b8dadba885fd23b0ff8aef0a0cf4bf15282b47b779f88
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 115552948
              windows:
                - start: "2026-10-22T04:55:52-07:00"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a16378-985a-76f0-ad76-6ef3e4dfec1e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 1726f861f9ce9080cfa0f957a9b25fc43cc9d3ff894ce378c1a63b24b9700dd3
              started: "2026-10-22T11:56:50.234Z"
              spawned: true
              bytes: 2170263
              windows:
                - start: "2026-10-22T11:56:50.234Z"
                  end: "2026-10-22T23:41:28-07:00"
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
                  end: "2026-10-22T23:41:28-07:00"
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
                  end: "2026-10-22T23:41:28-07:00"
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
                  end: "2026-10-22T23:41:28-07:00"
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
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a1638e-cd57-7dc1-897b-893fc3112bb1
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6e5921f3bd05652c6d20799a3ede34c9ed2df82423f23e6af78f6414bed1cbb3
              started: "2026-10-22T12:21:05.59Z"
              spawned: true
              bytes: 3362403
              windows:
                - start: "2026-10-22T12:21:05.59Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a1638f-48c4-7b70-8bd6-fcd4d9154e4b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: e7da4fd101c759892f4e37a8bad101d185c91694d3877c103770c806ec735763
              started: "2026-10-22T12:21:37.186Z"
              spawned: true
              bytes: 5348521
              windows:
                - start: "2026-10-22T12:21:37.186Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a16581-c3a0-7d91-b8cc-7370e4f9a388
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: f08c4168c76c8cb7bd108b96cc68b0753a2f39223b0a74a99f30fd69c543e7dd
              started: "2026-10-22T21:26:05.787Z"
              spawned: true
              bytes: 689933
              windows:
                - start: "2026-10-22T21:26:05.787Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a16590-7404-7410-8786-e00f43757dc5
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: eaccbce52bbfaf6bb551627eadba9e277dfbdf1dc368286c979fbfa4983628df
              started: "2026-10-22T21:42:08.267Z"
              spawned: true
              bytes: 1023075
              windows:
                - start: "2026-10-22T21:42:08.267Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a16757-eeb8-7c22-81ed-8ca60a3ab76d
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5e50a4b95341a68615c93c12db1633fe796a70d1cdbdd3e500ef030eccd914e3
              started: "2026-10-23T05:59:38.525Z"
              spawned: true
              bytes: 454873
              windows:
                - start: "2026-10-23T05:59:38.525Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a1675d-65b8-7733-8d95-fed455d12d74
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: d9ec0847e5bcbda2efe1a8824f4156a2a1103445466ed1704596c4d2c2fd76f8
              started: "2026-10-23T06:05:36.68Z"
              spawned: true
              bytes: 626239
              windows:
                - start: "2026-10-23T06:05:36.68Z"
                  end: "2026-10-22T23:41:28-07:00"
            - harness: codex
              id: 01a1676f-c412-78d2-aad9-5b8289acb4a4
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: c60ee3a9cf1e015e3abee6736d84b65cb8617ad18c7af00d96df08e83a70d4d8
              started: "2026-10-23T06:25:40.569Z"
              spawned: true
              bytes: 335938
              windows:
                - start: "2026-10-23T06:25:40.569Z"
                  end: "2026-10-22T23:41:28-07:00"
        queue_waits:
            - attempt_id: 03b79fe303c4473bd688542de9302c6b
              slot: parley.nvim:1
              record_digest: 93fa8a766d93cac1e26d50e8571ff57a0be03d26b614d37134716e1a7935e6cd
              start: "2026-10-22T14:45:52.190947Z"
              end: "2026-10-22T16:04:57.90039Z"
              queue_seconds: 4745.709443
              raw_seconds: 4745.709443
              exact: true
            - attempt_id: 5e80962d43811d5f3a8a39098aa0037c
              slot: parley.nvim:1
              record_digest: 99d7a927271707e8a83f72df76c243c25ff3ee7a06476b2b100c63ea4ee6c3d4
              start: "2026-10-22T16:35:46.792367Z"
              end: "2026-10-22T18:49:44.703658Z"
              queue_seconds: 8037.911291
              raw_seconds: 8037.911291
              exact: true
            - attempt_id: f2bf5c7b2996847ab0a5adcedf83cdb0
              slot: parley.nvim:1
              record_digest: 1640c77c9f4488d9f7ce03e484d0e8d7e04dcabcd4f0472c2da3b0f6ce4d78d5
              start: "2026-10-22T22:45:11.470906Z"
              end: "2026-10-23T00:48:47.140357Z"
              queue_seconds: 7415.669451
              raw_seconds: 7415.669451
              exact: true
        protected:
            - issue: "413"
              slot: parley.nvim:1
              start: "2026-10-22T19:56:15.6Z"
              end: "2026-10-22T20:09:41.441Z"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-23T01:01:43.764Z"
              end: "2026-10-22T18:11:02-07:00"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-22T18:11:02-07:00"
              end: "2026-10-23T01:34:34.464Z"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-23T01:04:05.561Z"
              end: "2026-10-22T18:11:02-07:00"
            - issue: "417"
              slot: parley.nvim:1
              start: "2026-10-22T18:11:02-07:00"
              end: "2026-10-23T01:22:49.851Z"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 256.6123
        cuts:
            - boundary: M1
              dispatched: "2026-10-22T06:06:25-07:00"
              finalized: "2026-10-22T06:12:16-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T06:30:25-07:00"
              finalized: "2026-10-22T06:35:03-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:04:21-07:00"
              finalized: "2026-10-22T07:09:19-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:19:27-07:00"
              finalized: "2026-10-22T07:26:19-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-22T07:46:18-07:00"
              finalized: "2026-10-22T07:49:52-07:00"
              finalizing: true
            - boundary: M2
              dispatched: "2026-10-22T23:20:36-07:00"
              finalized: "2026-10-22T23:24:09-07:00"
              finalizing: false
      "n": 7
      timestamp: "2026-10-22T23:46:36-07:00"
      dispatched: "2026-10-22T23:42:06-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-8
          disposition: addressed
          note: remote_session.lua:378-388 reports unavailable discovery and rejected attachment through one incarnation-owned notice. remote_session_native_spec.lua:133-200 covers failure classes, silent absence, deduplication and reopen. Removing the correction in a disposable pinned-head copy produced five regression failures with zero errors; all 21 native lifecycle cases pass at head.
          round: 7
        - id: BR-9
          disposition: addressed
          note: README.md:216-230 now documents the Pair bridge build, real --editor-endpoints --bridge invocation, absolute executable requirement, native nvim selection through PATH, and optional --couch candidate. These instructions match the driver's argument validation and atlas/modes/remote_session.md. Inspection establishes this prose-only correction without a wording-presence test.
          round: 7
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      reviewed: 4508683883564bbd676e42c2ee50d15935a95454
      blocked: false
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

## Round 2 — 2026-10-22T06:35:03-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — Queued publication and acquisition cancellation are fixed, with regressions that fail against the previous dispatcher. However, remote_session.lua:229 discards runtime.listen's operation handle; release_consumer at lines 36–44 cancels only acquisition, whose handle is cleared at line 92. A controlled native probe held first-listener reservation fsync, detached the final consumer, then released completion: cancellation calls were 0 and serverstart calls after detach were 1. Retain and cancel/join listener startup operations too, prevent subsequent startup effects after retirement, and add controlled reservation/publication cancellation tests. This remains the existing retirement-cancels-unstarted-effects family finding (ARCH-ORDER, ARCH-PURPOSE).
- BR-2 — addressed — remote_runtime.lua carries the acquisition deadline into first-listener publication and clears it only after durable success. Both reservation and publication regressions pass at head and fail with the previous runtime loaded: 22 passed, 2 failed, 0 errors.
- BR-3 — addressed — The plan's authoritative table now locates RuntimeOwnershipRecord in remote_runtime_record.lua:22, matching its computational codec and cleanup decision. The integration inventory at line 34 also names remote_runtime.lua's ownership shell. Both PURE entities have direct tests without IO dependencies.
- BR-4 — addressed — Final consumer drain now closes the exact runtime without global frontend.close. The ordinary-detach regression at remote_session_spec.lua:426 passes at head and fails against the previous dispatcher; terminal-resource and attach-during-drain regressions also fail against that dispatcher.
- BR-5 — addressed — README.md:208–213 documents --editor-endpoints --fake-only and the deferred producer/bridge prerequisites. This matches the script's options and the exercised fake/native probe, including its corrupt-reply negative control.

## Round 3 — 2026-10-22T07:09:19-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Exact listener handles are retained and canceled at remote_session.lua:43. Removing that call produced five dispatcher failures; reverting runtime finalization produced nine runtime failures. Pinned-head tests pass, including live-keeper continuity, reservation cleanup and slot reuse.
- BR-2 — addressed — Acquisition carries ctx.deadline into resource.startup_deadline and the first listener transaction. Reservation/publication deadline regressions pass on both supported runtimes.
- BR-3 — addressed — The pinned before/after diff corrects the Core concepts passage to RuntimeOwnershipRecord at lua/parley/remote_runtime_record.lua; that module implements the pure codec and cleanup decision.
- BR-4 — addressed — Last-consumer draining reaches exact runtime close. The regression at remote_session_spec.lua:422 verifies removal of the final socket, marker and directory without closing the editor.
- BR-5 — addressed — README.md:208 documents --editor-endpoints --fake-only and the real-producer prerequisites. The documented command passes and rejects its deliberately corrupted reply.

### Raised

- **BR-6** [Important] `validated-authority-outcomes` (kind: defect) A rejected canonical-file acknowledgment is still reported as confirmed
  At lua/parley/remote_session.lua:131-135, dispatch can reject a binding whose File differs from the attachment identity, yet the shell checks and reports the original confirmed result. remote_session_model.lua:285 also stores that rejected result unchanged. A disposable native probe returning File=/different-document.md observed callback=confirmed and phase=unconfirmed, without an unavailable notice. Normalize rejected confirmations through the model’s accepted outcome, use that outcome for callbacks and notices, and add a dispatcher regression. ARCH-SECURE, ARCH-ORDER.

## Round 4 — 2026-10-22T07:26:19-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Exact listener cancellation remains implemented; queued-publication, held-startup, reservation/publication cancellation, and slot-reuse regressions pass on both runtimes.
- BR-2 — addressed — Acquisition passes its absolute deadline into first-listener publication; reservation and publication deadline regressions pass on both runtimes.
- BR-3 — addressed — The Core concepts table names lua/parley/remote_runtime_record.lua, whose implementation contains the pure ownership codec and cleanup decision.
- BR-4 — addressed — remote_session_spec.lua:462 verifies final detach removes the listener, marker, and directory without closing the editor; it passes on both runtimes.
- BR-5 — addressed — README.md:208 documents --editor-endpoints --fake-only and the deferred real prerequisites; the documented command passes its positive and corrupt-reply controls.
- BR-6 — addressed — Model normalization and shell consumption of snapshot().result are reachable. Removing the correction produces 12 model failures and one dispatcher failure; pinned-head regressions pass.

### Raised

- **BR-7** [Critical] `validate-before-resource-allocation` (kind: defect) Unsupported attachment paths throw after listener creation and wedge the dispatcher
  lua/parley/remote_session.lua:197-200 validates Namespace and DocumentID but not File against the complete attachment-context contract. A real canonical filename containing a newline passes preflight, starts a listener, then throws at model.new on line 238 because remote_session_model.lua:47 rejects that spelling. The exception skips done(listening) at line 254, leaving io_busy set. Native probes on 0.12.5 and 0.11.7 observed invalid attachment context, no attachment callback, and no subsequent ordinary-attachment or close callback. Validate the complete context through shared pure validation before allocating resources, handle rejected construction through normal cleanup/completion, and add a sequence regression proving a rejected attachment cannot block later attachment or close. ARCH-SECURE, ARCH-ORDER.

## Round 5 — 2026-10-22T07:49:52-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Existing cancellation regressions pass, including held acquisition, queued registration, all four listener startup boundaries, cleanup joining and slot reuse.
- BR-2 — addressed — remote_runtime.lua carries startup_deadline through first-listener durability; reservation and publication deadline regressions pass on both runtimes.
- BR-3 — addressed — The plan's Pure entities table identifies remote_runtime_record.lua as RuntimeOwnershipRecord's location; that module implements the codec and cleanup decision.
- BR-4 — addressed — Last-consumer drain closes the runtime automatically; final-detach cleanup and attach-during-drain regressions pass on both runtimes.
- BR-5 — addressed — README.md documents --editor-endpoints --fake-only and the deferred real prerequisites; the parser implements that invocation and its fake conformance check passed.
- BR-6 — addressed — The model normalizes unowned confirmations before storing results, and the dispatcher consumes that accepted result. Mismatched-identity and canonical-file regressions pass.
- BR-7 — addressed — Shared validation precedes allocation and checks the allocated tuple; constructor refusal or exception follows cleanup/completion. Removing the production fix in a disposable checkout caused six pure failures and four native continuation failures, with zero test errors. Pinned-head tests pass.

## Round 6 — 2026-10-22T23:24:09-07:00 (codex) — BLOCKED

### Raised

- **BR-8** [Important] `visible-remote-availability-failures` (kind: defect) Report unavailable outside-pane discovery
  lua/parley/remote_session.lua:370-374 handles only registered results and silently drops unavailable discovery, contradicting the plan's promised remote-unavailable notice. A production-observe probe returning unavailable produced one lookup, zero notices and zero allocations; duplicate observe did not retry. ARCH-PURPOSE, ARCH-SECURE: distinguish positive absence from discovery failure, emit one bounded notice per buffer incarnation, and sweep discovery-to-attachment rejection paths. Add regressions covering timeout/malformed results, silent positive absence, and duplicate-event deduplication.
- **BR-9** [Important] `readme-runnable-surface-documentation` (kind: defect) Document the required real-conformance bridge invocation in README
  scripts/check-couch-registry-conformance.py:175-186 adds --bridge and requires it for real endpoint conformance, but README.md:213-218 still documents only fake-only execution and prerequisites; README is unchanged in this range. This is the 2nd finding in family readme-runnable-surface-documentation. Earlier rounds fixed instances. State and apply the rule across the changed runnable surface: every introduced or changed invocation must have usable README guidance. Document the real command, absolute bridge requirement and native Neovim selection; atlas/modes/remote_session.md already supplies the concrete referent. No wording-presence test is needed.

## Round 7 — 2026-10-22T23:46:36-07:00 (codex) — passed

### Disposed

- BR-8 — addressed — remote_session.lua:378-388 reports unavailable discovery and rejected attachment through one incarnation-owned notice. remote_session_native_spec.lua:133-200 covers failure classes, silent absence, deduplication and reopen. Removing the correction in a disposable pinned-head copy produced five regression failures with zero errors; all 21 native lifecycle cases pass at head.
- BR-9 — addressed — README.md:216-230 now documents the Pair bridge build, real --editor-endpoints --bridge invocation, absolute executable requirement, native nvim selection through PATH, and optional --couch candidate. These instructions match the driver's argument validation and atlas/modes/remote_session.md. Inspection establishes this prose-only correction without a wording-presence test.

## Open findings

(none — every finding has been disposed)
