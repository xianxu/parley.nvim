---
gate: boundary-review
issue: 410
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 008812c4-feb7-4fd2-9bf7-47e5b2a1a62a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/eb5b13688580f6b8
            reviewed_head: adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6
            slot: parley.nvim:4
            requested_at: "2026-10-22T19:16:34.97545Z"
          phase: finished
          pid: 96134
          started_at: "2026-10-22T19:16:35.074286Z"
          finished_at: "2026-10-22T19:22:16.753209Z"
          session_id: 01a1650b-338a-7fe3-b6b7-d627a5de240d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6
        tracker_head: d6b0e05f6a0105af4993ad21ab2460c82b69e5f3
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T12:16:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T12:16:18-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 173538876ca11b601c31fb0966f96c2d149ac17c4244924bd0cf16c734582568
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 3235289
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T12:16:18-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: 0aaf2a7cb03a256a17dbace202bfda1f8b7fae2b6c11bc1024ae08abc3c36fa3
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 1166238
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T12:16:18-07:00"
      "n": 1
      timestamp: "2026-10-22T12:22:24-07:00"
      dispatched: "2026-10-22T12:16:34-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Existing session-sync controllers bypass pending-lookup admission
          detail: 'lua/parley/session_sync.lua:726 updates an existing controller''s identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper''s detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.'
          family: admission-handoff-covers-existing-controllers
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c6e20723-aa74-4785-b71b-c902edaa45df
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/8442cc1717c71343
            reviewed_head: 8f42416fc1223719f4a1de940185280f3f8ea844
            slot: parley.nvim:4
            requested_at: "2026-10-22T19:52:00.202536Z"
          phase: finished
          pid: 37065
          started_at: "2026-10-22T19:52:00.430149Z"
          finished_at: "2026-10-22T20:02:13.374958Z"
          session_id: 01a1652b-a28f-7062-b338-c0e1748750b7
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8f42416fc1223719f4a1de940185280f3f8ea844
        tracker_head: e53fe815150ced405d14310e9a1e790fcde940b1
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T12:51:25-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T12:51:25-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 89570c456cce9d96392d52d7124b864483c948bc947b4f4e68afe8cd0b6e36a4
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 6355929
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T12:51:25-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: 65c596d09a970f34c1f3c475dbcd5632ee74799904a087511ebb61ec0ba67aad
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 2026555
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T12:51:25-07:00"
            - harness: codex
              id: 01a16516-448a-7a02-a048-a98b58514a1c
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ba427ff29c65fc5302b19bb42f2a683a55bb20a0d7e97a96f808eba5de8f835f
              started: "2026-10-22T19:28:41.183Z"
              spawned: false
              bytes: 537917
              windows:
                - start: "2026-10-22T19:28:41.183Z"
                  end: "2026-10-22T12:51:25-07:00"
            - harness: codex
              id: 01a1651d-0d5d-7983-aea8-b86ee0c93ee2
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 84b157e9f00a6f4919bf6c5c1ac648eca3a13fee9b0c66827496ad0938eced8a
              started: "2026-10-22T19:36:05.627Z"
              spawned: false
              bytes: 475089
              windows:
                - start: "2026-10-22T19:36:05.627Z"
                  end: "2026-10-22T12:51:25-07:00"
            - harness: codex
              id: 01a1651e-ae65-7bd1-a0ec-fac87785e922
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c25c2bfa57d32defb477ef89f6a6e67896cad894a6d41003052632c815c43ee1
              started: "2026-10-22T19:37:52.331Z"
              spawned: false
              bytes: 492047
              windows:
                - start: "2026-10-22T19:37:52.331Z"
                  end: "2026-10-22T12:51:25-07:00"
            - harness: codex
              id: 01a1651f-3024-7de0-bd64-012aab41bfd4
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cd78e5bafcd5c5baf4ce559eb56adfd161f10a4bf5b53368a6ba93f89c005739
              started: "2026-10-22T19:38:25.45Z"
              spawned: false
              bytes: 436918
              windows:
                - start: "2026-10-22T19:38:25.45Z"
                  end: "2026-10-22T12:51:25-07:00"
        cuts:
            - dispatched: "2026-10-22T12:16:34-07:00"
              finalized: "2026-10-22T12:22:24-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T13:02:18-07:00"
      dispatched: "2026-10-22T12:52:00-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Existing-controller attachment now consumes the input scope and observed edits. Production-order regressions pass on Neovim 0.11.7 and 0.12.5; substituting the pre-correction c8e811f1 modules makes the clean-input, saved-edit, and pre-owned-turn regressions fail.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Critical
          title: Deferred legacy edit turns remain unlocked after lookup completes without registration
          detail: 'lua/parley/session_sync.lua:797-799 records an observed turn and suppresses legacy protection while lookup is pending. Background lookup completion at lua/parley/agentic_document.lua:347-355 has no continuation restoring that protection on absence; only an active InsertEnter waiter resumes legacy behavior. The existing tests/integration/session_sync_spec.lua:411 regression fails at head with a missing .lock, and an isolated check confirms pending=false, no registered identity, and lock=0 after completion. The same test passes with pre-correction c8e811f1 modules. This violates the plan''s promise that proven absence restores existing legacy behavior and leaves outstanding edits without their previous protection. ARCH-PURPOSE / ARCH-ORDER: this is the 2nd finding in family admission-handoff-covers-existing-controllers. Earlier rounds fixed instances. Do NOT fix only this test: state and enforce the rule for settling deferred turns across lookup outcomes, normal-mode edits, and completion after input-scope expiry, preserving the original baseline and ownership checks.'
          family: admission-handoff-covers-existing-controllers
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 0fed17ef-288e-441c-a375-0134179812d4
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/97c94788183d1112
            reviewed_head: 199c3b90373e3007fc023d50a8f00652588aec93
            slot: parley.nvim:4
            requested_at: "2026-10-22T20:48:03.329318Z"
          phase: finished
          pid: 42890
          started_at: "2026-10-22T20:48:03.550171Z"
          finished_at: "2026-10-22T20:55:36.231223Z"
          session_id: 01a1655e-f47d-7e60-afe8-4a65966e1e03
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 199c3b90373e3007fc023d50a8f00652588aec93
        tracker_head: fdbdb66846674a32f02b12fd9397c16d8f14c118
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T13:47:20-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T13:47:20-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: d4e9ebe66af57fe31cadda6f689074caeb1d090c9d5957350b379cce2cb82fd3
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 11102130
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: f55bc1cd4d79ab2655d394b43a9daba9cc1a2d770f9b0def531fa1f6623cd35c
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 2802985
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a16516-448a-7a02-a048-a98b58514a1c
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ba427ff29c65fc5302b19bb42f2a683a55bb20a0d7e97a96f808eba5de8f835f
              started: "2026-10-22T19:28:41.183Z"
              spawned: false
              bytes: 537917
              windows:
                - start: "2026-10-22T19:28:41.183Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a1651d-0d5d-7983-aea8-b86ee0c93ee2
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 84b157e9f00a6f4919bf6c5c1ac648eca3a13fee9b0c66827496ad0938eced8a
              started: "2026-10-22T19:36:05.627Z"
              spawned: false
              bytes: 475089
              windows:
                - start: "2026-10-22T19:36:05.627Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a1651e-ae65-7bd1-a0ec-fac87785e922
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c25c2bfa57d32defb477ef89f6a6e67896cad894a6d41003052632c815c43ee1
              started: "2026-10-22T19:37:52.331Z"
              spawned: false
              bytes: 492047
              windows:
                - start: "2026-10-22T19:37:52.331Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a1651f-3024-7de0-bd64-012aab41bfd4
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cd78e5bafcd5c5baf4ce559eb56adfd161f10a4bf5b53368a6ba93f89c005739
              started: "2026-10-22T19:38:25.45Z"
              spawned: false
              bytes: 436918
              windows:
                - start: "2026-10-22T19:38:25.45Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a16544-6bda-78c2-a06d-1ff41aeeabf3
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 3ab0aa111ab785bd467edd3e39f9764429a939c6107aa612f319463c35e60cb1
              started: "2026-10-22T20:19:05.756Z"
              spawned: false
              bytes: 536046
              windows:
                - start: "2026-10-22T20:19:05.756Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a16545-87fc-7dd3-994a-55bfc038921a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: a030eb7a72bffb6321b7e8f494daa5c6f4f13f2bca9dc225db876c80928373c8
              started: "2026-10-22T20:20:18.403Z"
              spawned: false
              bytes: 511887
              windows:
                - start: "2026-10-22T20:20:18.403Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a16546-f538-7af2-b3c4-0433e3ebee44
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c59ce6dbeeebf908f119e4abcd0bd59a530d70ecb69672eb22dae9faa1c2fd62
              started: "2026-10-22T20:21:52.35Z"
              spawned: false
              bytes: 539492
              windows:
                - start: "2026-10-22T20:21:52.35Z"
                  end: "2026-10-22T13:47:20-07:00"
            - harness: codex
              id: 01a16547-83ae-7082-98fd-6589a755a44f
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 0de7c4cff46d7e25e8832b814f832e3cc0b2a70e8aff9ba3a44a197b50a4c00e
              started: "2026-10-22T20:22:28.664Z"
              spawned: false
              bytes: 525672
              windows:
                - start: "2026-10-22T20:22:28.664Z"
                  end: "2026-10-22T13:47:20-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 19.17791666666667
        cuts:
            - dispatched: "2026-10-22T12:16:34-07:00"
              finalized: "2026-10-22T12:22:24-07:00"
              finalizing: false
            - dispatched: "2026-10-22T12:52:00-07:00"
              finalized: "2026-10-22T13:02:18-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-22T13:55:43-07:00"
      dispatched: "2026-10-22T13:48:03-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: S1-first setup and guarded legacy attachment preserve the correction; queued-first-input tests pass for parent, side, and directly attached documents on both runtimes.
          round: 3
        - id: BR-2
          disposition: addressed
          note: The approved RETIRE revision explicitly replaces legacy restoration with editable, visibly unprotected S1 ownership. Pending/absent/unavailable regressions fail against pre-correction modules and pass at head; late saved-edit reconciliation and explicit old-turn completion also pass.
          round: 3
      findings:
        - kind: defect
          id: BR-3
          severity: Important
          title: Standalone recovery documentation omits required environment conditions
          detail: 'README.md:98 and atlas/modes/session_sync.md:119 say to open nvim outside Couch but omit the scope/tag condition explicitly required by workshop/plans/000410-pending-lookup-admission-plan.md:303. Couch context is inherited through environment variables (lua/parley/couch.lua:202); the successful restart regression explicitly clears both variables at tests/integration/session_sync_native_spec.lua:335. Add `env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md` to both recovery passages so readers can reach the advertised standalone release route. ARCH-PURPOSE: complete the agreed recovery workflow.'
          family: recovery-guidance-names-launch-context
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 0b20d9e0-06e7-4bfc-8195-438a351cd3a8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/ee532ee4d33ebdc5
            reviewed_head: bca7cf786a290f84c66037f358cd20b2475515da
            slot: parley.nvim:4
            requested_at: "2026-10-22T21:00:30.466242Z"
          phase: finished
          pid: 26589
          started_at: "2026-10-22T21:00:30.640011Z"
          finished_at: "2026-10-22T21:06:37.962134Z"
          session_id: 01a1656a-5a16-7970-b93a-fb96e742349a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: bca7cf786a290f84c66037f358cd20b2475515da
        tracker_head: c10902421d1e12272b97dac2b97f5fd8b119b2d4
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T13:59:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T13:59:55-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: d3edcd505970267d501885c5247b5f4527729a929bb574561e019979049a4689
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 11793514
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: f55bc1cd4d79ab2655d394b43a9daba9cc1a2d770f9b0def531fa1f6623cd35c
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 2802985
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a16516-448a-7a02-a048-a98b58514a1c
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ba427ff29c65fc5302b19bb42f2a683a55bb20a0d7e97a96f808eba5de8f835f
              started: "2026-10-22T19:28:41.183Z"
              spawned: false
              bytes: 537917
              windows:
                - start: "2026-10-22T19:28:41.183Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a1651d-0d5d-7983-aea8-b86ee0c93ee2
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 84b157e9f00a6f4919bf6c5c1ac648eca3a13fee9b0c66827496ad0938eced8a
              started: "2026-10-22T19:36:05.627Z"
              spawned: false
              bytes: 475089
              windows:
                - start: "2026-10-22T19:36:05.627Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a1651e-ae65-7bd1-a0ec-fac87785e922
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c25c2bfa57d32defb477ef89f6a6e67896cad894a6d41003052632c815c43ee1
              started: "2026-10-22T19:37:52.331Z"
              spawned: false
              bytes: 492047
              windows:
                - start: "2026-10-22T19:37:52.331Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a1651f-3024-7de0-bd64-012aab41bfd4
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cd78e5bafcd5c5baf4ce559eb56adfd161f10a4bf5b53368a6ba93f89c005739
              started: "2026-10-22T19:38:25.45Z"
              spawned: false
              bytes: 436918
              windows:
                - start: "2026-10-22T19:38:25.45Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a16544-6bda-78c2-a06d-1ff41aeeabf3
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 3ab0aa111ab785bd467edd3e39f9764429a939c6107aa612f319463c35e60cb1
              started: "2026-10-22T20:19:05.756Z"
              spawned: false
              bytes: 536046
              windows:
                - start: "2026-10-22T20:19:05.756Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a16545-87fc-7dd3-994a-55bfc038921a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: a030eb7a72bffb6321b7e8f494daa5c6f4f13f2bca9dc225db876c80928373c8
              started: "2026-10-22T20:20:18.403Z"
              spawned: false
              bytes: 511887
              windows:
                - start: "2026-10-22T20:20:18.403Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a16546-f538-7af2-b3c4-0433e3ebee44
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c59ce6dbeeebf908f119e4abcd0bd59a530d70ecb69672eb22dae9faa1c2fd62
              started: "2026-10-22T20:21:52.35Z"
              spawned: false
              bytes: 539492
              windows:
                - start: "2026-10-22T20:21:52.35Z"
                  end: "2026-10-22T13:59:55-07:00"
            - harness: codex
              id: 01a16547-83ae-7082-98fd-6589a755a44f
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 0de7c4cff46d7e25e8832b814f832e3cc0b2a70e8aff9ba3a44a197b50a4c00e
              started: "2026-10-22T20:22:28.664Z"
              spawned: false
              bytes: 525672
              windows:
                - start: "2026-10-22T20:22:28.664Z"
                  end: "2026-10-22T13:59:55-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 34.2714
        cuts:
            - dispatched: "2026-10-22T12:16:34-07:00"
              finalized: "2026-10-22T12:22:24-07:00"
              finalizing: false
            - dispatched: "2026-10-22T12:52:00-07:00"
              finalized: "2026-10-22T13:02:18-07:00"
              finalizing: false
            - dispatched: "2026-10-22T13:48:03-07:00"
              finalized: "2026-10-22T13:55:43-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-22T14:06:39-07:00"
      dispatched: "2026-10-22T14:00:30-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-3
          disposition: addressed
          note: The pinned documentation diff adds env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md at README.md:103 and atlas/modes/session_sync.md:124. This matches couch.thread() at lua/parley/couch.lua:202 and the restarted standalone recovery fixture at tests/integration/session_sync_native_spec.lua:335. The recovery regression passed on both runtimes; this correction changes prose only.
          round: 4
      recipe: milestone-review
      isolation: fenced
      reviewed: bca7cf786a290f84c66037f358cd20b2475515da
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6ca82bf9-94fd-4da9-8fa6-6035a6772d36
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: fix-review
            round: 5
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/60fe1ad57d185b2b
            reviewed_head: 7b8452dfc3fa90be1118d1d07aac6c5881cb038b
            slot: parley.nvim:4
            requested_at: "2026-10-22T23:28:48.487634Z"
          phase: finished
          pid: 13572
          started_at: "2026-10-22T23:28:48.581154Z"
          finished_at: "2026-10-22T23:29:34.209571Z"
          session_id: 01a165f2-1ed2-70e1-b043-d3ffcf4bf3e8
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 7b8452dfc3fa90be1118d1d07aac6c5881cb038b
        tracker_head: 1536339e405ab6f62ea7e6fcebe1da00b51a0dd5
        branch_point: 1752271061691fd0780994a45b93d46463c8c747
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T16:27:42-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T16:27:42-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e94f8adb2a7986b9bfcd22b6ee18f1467894e38c91a66f67beb9f8a3559d72b6
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 15773321
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: 40fccf72846705b5658fccf70aa70c0a58cc3ec62cc652a26c152d05b6f9cbca
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 3089219
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a16516-448a-7a02-a048-a98b58514a1c
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ba427ff29c65fc5302b19bb42f2a683a55bb20a0d7e97a96f808eba5de8f835f
              started: "2026-10-22T19:28:41.183Z"
              spawned: false
              bytes: 537917
              windows:
                - start: "2026-10-22T19:28:41.183Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a1651d-0d5d-7983-aea8-b86ee0c93ee2
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 84b157e9f00a6f4919bf6c5c1ac648eca3a13fee9b0c66827496ad0938eced8a
              started: "2026-10-22T19:36:05.627Z"
              spawned: false
              bytes: 475089
              windows:
                - start: "2026-10-22T19:36:05.627Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a1651e-ae65-7bd1-a0ec-fac87785e922
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c25c2bfa57d32defb477ef89f6a6e67896cad894a6d41003052632c815c43ee1
              started: "2026-10-22T19:37:52.331Z"
              spawned: false
              bytes: 492047
              windows:
                - start: "2026-10-22T19:37:52.331Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a1651f-3024-7de0-bd64-012aab41bfd4
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cd78e5bafcd5c5baf4ce559eb56adfd161f10a4bf5b53368a6ba93f89c005739
              started: "2026-10-22T19:38:25.45Z"
              spawned: false
              bytes: 436918
              windows:
                - start: "2026-10-22T19:38:25.45Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a16544-6bda-78c2-a06d-1ff41aeeabf3
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 3ab0aa111ab785bd467edd3e39f9764429a939c6107aa612f319463c35e60cb1
              started: "2026-10-22T20:19:05.756Z"
              spawned: false
              bytes: 536046
              windows:
                - start: "2026-10-22T20:19:05.756Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a16545-87fc-7dd3-994a-55bfc038921a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: a030eb7a72bffb6321b7e8f494daa5c6f4f13f2bca9dc225db876c80928373c8
              started: "2026-10-22T20:20:18.403Z"
              spawned: false
              bytes: 511887
              windows:
                - start: "2026-10-22T20:20:18.403Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a16546-f538-7af2-b3c4-0433e3ebee44
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c59ce6dbeeebf908f119e4abcd0bd59a530d70ecb69672eb22dae9faa1c2fd62
              started: "2026-10-22T20:21:52.35Z"
              spawned: false
              bytes: 539492
              windows:
                - start: "2026-10-22T20:21:52.35Z"
                  end: "2026-10-22T16:27:42-07:00"
            - harness: codex
              id: 01a16547-83ae-7082-98fd-6589a755a44f
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 0de7c4cff46d7e25e8832b814f832e3cc0b2a70e8aff9ba3a44a197b50a4c00e
              started: "2026-10-22T20:22:28.664Z"
              spawned: false
              bytes: 525672
              windows:
                - start: "2026-10-22T20:22:28.664Z"
                  end: "2026-10-22T16:27:42-07:00"
        queue_waits:
            - attempt_id: 89936e0b5bf67bf6d2774e7657dca8f1
              slot: parley.nvim:4
              record_digest: 9272bef96a3640321cf0e71235a24f28d4ed7cf5da8c26bd3124d0c7bfdc9810
              start: "2026-10-22T20:41:42.901141Z"
              end: "2026-10-22T23:08:25.32433Z"
              queue_seconds: 8802.423189
              raw_seconds: 8802.423189
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 79.82053333333333
        cuts:
            - dispatched: "2026-10-22T12:16:34-07:00"
              finalized: "2026-10-22T12:22:24-07:00"
              finalizing: false
            - dispatched: "2026-10-22T12:52:00-07:00"
              finalized: "2026-10-22T13:02:18-07:00"
              finalizing: false
            - dispatched: "2026-10-22T13:48:03-07:00"
              finalized: "2026-10-22T13:55:43-07:00"
              finalizing: false
            - dispatched: "2026-10-22T14:00:30-07:00"
              finalized: "2026-10-22T14:06:39-07:00"
              finalizing: true
      "n": 5
      timestamp: "2026-10-22T16:29:34-07:00"
      dispatched: "2026-10-22T16:28:48-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      recipe: fix-review
      isolation: fenced
      reviewed: 7b8452dfc3fa90be1118d1d07aac6c5881cb038b
      blocked: false
---

# Gate ledger — parley.nvim#410 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T12:22:24-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `admission-handoff-covers-existing-controllers` (kind: defect) Existing session-sync controllers bypass pending-lookup admission
  lua/parley/session_sync.lua:726 updates an existing controller's identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper's detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.

## Round 2 — 2026-10-22T13:02:18-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Existing-controller attachment now consumes the input scope and observed edits. Production-order regressions pass on Neovim 0.11.7 and 0.12.5; substituting the pre-correction c8e811f1 modules makes the clean-input, saved-edit, and pre-owned-turn regressions fail.

### Raised

- **BR-2** [Critical] `admission-handoff-covers-existing-controllers` (kind: defect) Deferred legacy edit turns remain unlocked after lookup completes without registration
  lua/parley/session_sync.lua:797-799 records an observed turn and suppresses legacy protection while lookup is pending. Background lookup completion at lua/parley/agentic_document.lua:347-355 has no continuation restoring that protection on absence; only an active InsertEnter waiter resumes legacy behavior. The existing tests/integration/session_sync_spec.lua:411 regression fails at head with a missing .lock, and an isolated check confirms pending=false, no registered identity, and lock=0 after completion. The same test passes with pre-correction c8e811f1 modules. This violates the plan's promise that proven absence restores existing legacy behavior and leaves outstanding edits without their previous protection. ARCH-PURPOSE / ARCH-ORDER: this is the 2nd finding in family admission-handoff-covers-existing-controllers. Earlier rounds fixed instances. Do NOT fix only this test: state and enforce the rule for settling deferred turns across lookup outcomes, normal-mode edits, and completion after input-scope expiry, preserving the original baseline and ownership checks.

## Round 3 — 2026-10-22T13:55:43-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — S1-first setup and guarded legacy attachment preserve the correction; queued-first-input tests pass for parent, side, and directly attached documents on both runtimes.
- BR-2 — addressed — The approved RETIRE revision explicitly replaces legacy restoration with editable, visibly unprotected S1 ownership. Pending/absent/unavailable regressions fail against pre-correction modules and pass at head; late saved-edit reconciliation and explicit old-turn completion also pass.

### Raised

- **BR-3** [Important] `recovery-guidance-names-launch-context` (kind: defect) Standalone recovery documentation omits required environment conditions
  README.md:98 and atlas/modes/session_sync.md:119 say to open nvim outside Couch but omit the scope/tag condition explicitly required by workshop/plans/000410-pending-lookup-admission-plan.md:303. Couch context is inherited through environment variables (lua/parley/couch.lua:202); the successful restart regression explicitly clears both variables at tests/integration/session_sync_native_spec.lua:335. Add `env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md` to both recovery passages so readers can reach the advertised standalone release route. ARCH-PURPOSE: complete the agreed recovery workflow.

## Round 4 — 2026-10-22T14:06:39-07:00 (codex) — passed

### Disposed

- BR-3 — addressed — The pinned documentation diff adds env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md at README.md:103 and atlas/modes/session_sync.md:124. This matches couch.thread() at lua/parley/couch.lua:202 and the restarted standalone recovery fixture at tests/integration/session_sync_native_spec.lua:335. The recovery regression passed on both runtimes; this correction changes prose only.

## Round 5 — 2026-10-22T16:29:34-07:00 (codex) — passed

## Open findings

(none — every finding has been disposed)
