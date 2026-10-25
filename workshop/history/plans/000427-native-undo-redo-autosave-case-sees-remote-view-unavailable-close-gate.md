---
gate: boundary-review
issue: 427
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8d24ac63-3407-422e-96a8-dec990572447
            repository: github.com/xianxu/parley.nvim
            issue_id: "000427"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/813109e351977a07
            reviewed_head: cc2a2619f97fbf3769e1bbc0bf1e75e7aa0cca3b
            slot: parley.nvim:1
            requested_at: "2026-10-24T20:25:56.95457Z"
          phase: finished
          pid: 29049
          started_at: "2026-10-24T20:25:57.105481Z"
          finished_at: "2026-10-24T20:41:37.312667Z"
          session_id: ec676a6a-a555-4d90-8853-257e1d51d7bf
          outcome: returned
      actual_inputs:
        version: 3
        method: active-time-v3-branch-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: cc2a2619f97fbf3769e1bbc0bf1e75e7aa0cca3b
        tracker_head: d9d089569815bbb4e353422944c5f81d059d543f
        branch_point: 3f473ba25d41804fc1cdcf1b7ced8d514947c092
        since: "2026-10-24T10:09:05-07:00"
        until: "2026-10-24T13:24:26-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-24T10:09:05-07:00"
              end: "2026-10-24T13:24:26-07:00"
              began: "2026-10-24T10:09:05-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 4effc01200b5dc68991e13d3ec4e3a551ebae1b1bc5197e2ce6866543fbabfdc
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 17985674
              windows:
                - start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
              dispatch_windows:
                - start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T13:24:26-07:00"
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: cc2a2619f97fbf3769e1bbc0bf1e75e7aa0cca3b
              branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
              digest: 1afc42aec63a2f4bc43f0fb4d9d7be97775733bd30c6c51757d01beaaf927020
              bytes: 161852
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/d993777e-4c43-455a-b373-52b1dc0fc833
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d993777e-4c43-455a-b373-52b1dc0fc833
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:24:26-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
        queue_waits:
            - attempt_id: 02737399d838d3e47d85f9654546019a
              slot: parley.nvim:1
              record_digest: 912de3638b23a10aac373a0450437f93778f702eff51ecb17a284a29b2e4f308
              start: "2026-10-24T18:59:40.694176Z"
              end: "2026-10-24T20:13:49.882693Z"
              queue_seconds: 4449.188517
              raw_seconds: 4449.188517
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.08641666666666667
      "n": 1
      timestamp: "2026-10-24T13:41:38-07:00"
      dispatched: "2026-10-24T13:25:56-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: No committed test fails without the fake-lookup fix; only an uncommitted 200 ms wait showed red
          detail: Restoring tests/helpers/fake_couch.lua from base 3f473ba2 and running make test-spec SPEC=modes/session_sync exits 0 with zero failures. The control at session_sync_native_spec.lua:1744 opts into legacy, so it passes on either fake. The undo/redo cases check for notices before the lookup reply arrives. Add a default-fake test that waits until the unregistered open's lookup has finished (poll, do not sleep) and then asserts notifications == {}. That test fails on the old fake every time. This is the only behavior change in the window, so there are no other instances.
          family: fix-without-failing-regression-test
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Plan and Log claims disagree with the code and the run (knob set/unset inverted, 154 vs 153 passes)
          detail: Plan item 3 says that with the knob set the lookup reports absent; it is the default (unset) that does. Item 2 says the lookup is unavailable with the knob unset; it takes FAKE_COUCH_LOOKUP=legacy. The Log says 154 native passes; the run at head shows 153/0/0.
          family: doc-claim-unverified
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5346ba91-2bbf-4324-941a-e7e0ace61b3b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000427"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/fad919e42e1ef628
            reviewed_head: 05be4ebadddea40cf7885e4cf4fadc780516ff0d
            slot: parley.nvim:1
            requested_at: "2026-10-24T20:49:44.033252Z"
          phase: finished
          pid: 36015
          started_at: "2026-10-24T20:49:44.179015Z"
          finished_at: "2026-10-24T21:06:23.314926Z"
          session_id: 8ab7b333-f214-46ff-aa41-b777c599643a
          outcome: returned
      actual_inputs:
        version: 3
        method: active-time-v3-branch-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 05be4ebadddea40cf7885e4cf4fadc780516ff0d
        tracker_head: 3e1200d0d98a205dcd36006e9469111e203eac21
        branch_point: 3f473ba25d41804fc1cdcf1b7ced8d514947c092
        since: "2026-10-24T10:09:05-07:00"
        until: "2026-10-24T13:45:57-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-24T10:09:05-07:00"
              end: "2026-10-24T13:45:57-07:00"
              began: "2026-10-24T10:09:05-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 1abe89456562fa99ebf7dbc2d5d2078c7c7f7358457e134be877206e3e4a80aa
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 18107563
              windows:
                - start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
              dispatch_windows:
                - start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T13:45:57-07:00"
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: 05be4ebadddea40cf7885e4cf4fadc780516ff0d
              branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
              digest: 6abb010e6d401c1682f00f1b003e731bb3e6336ad242c5ffcc63e62c9b442275
              bytes: 162057
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/d993777e-4c43-455a-b373-52b1dc0fc833
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d993777e-4c43-455a-b373-52b1dc0fc833
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T10:09:05-07:00"
                  end: "2026-10-24T17:09:25Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T17:09:25Z"
                  end: "2026-10-24T13:45:57-07:00"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: branch
        queue_waits:
            - attempt_id: 02737399d838d3e47d85f9654546019a
              slot: parley.nvim:1
              record_digest: 912de3638b23a10aac373a0450437f93778f702eff51ecb17a284a29b2e4f308
              start: "2026-10-24T18:59:40.694176Z"
              end: "2026-10-24T20:13:49.882693Z"
              queue_seconds: 4449.188517
              raw_seconds: 4449.188517
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.08641666666666667
        cuts:
            - dispatched: "2026-10-24T13:25:56-07:00"
              finalized: "2026-10-24T13:41:38-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-24T14:06:25-07:00"
      dispatched: "2026-10-24T13:49:44-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Base fake restored at head: the new case and checktime autosave=true fail (exit 2); head fake gives 154 pass, 0 fail.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: Plan items 2 and 3 now match the fake's knob semantics; the Log's 154 matches the head run on nvim 0.11.7.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Minor
          title: The Log says only the new case fails on the base fake, but the base-fake run also failed checktime autosave=true
          detail: 'This is the 2nd finding in family doc-claim-unverified. The rule: a Log claim about a test run states that run''s outcome (its counts and which cases failed), not that a set of failures is exclusive. Running the base fake here also failed the racy checktime autosave=true case. No other instance in this window: the counts 25 and 154 and the 37/14/23 ms figures were checked.'
          family: doc-claim-unverified
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 05be4ebadddea40cf7885e4cf4fadc780516ff0d
      blocked: false
---

# Gate ledger — parley.nvim#427 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-24T13:41:38-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `fix-without-failing-regression-test` (kind: defect) No committed test fails without the fake-lookup fix; only an uncommitted 200 ms wait showed red
  Restoring tests/helpers/fake_couch.lua from base 3f473ba2 and running make test-spec SPEC=modes/session_sync exits 0 with zero failures. The control at session_sync_native_spec.lua:1744 opts into legacy, so it passes on either fake. The undo/redo cases check for notices before the lookup reply arrives. Add a default-fake test that waits until the unregistered open's lookup has finished (poll, do not sleep) and then asserts notifications == {}. That test fails on the old fake every time. This is the only behavior change in the window, so there are no other instances.
- **BR-2** [Minor] `doc-claim-unverified` (kind: defect) Plan and Log claims disagree with the code and the run (knob set/unset inverted, 154 vs 153 passes)
  Plan item 3 says that with the knob set the lookup reports absent; it is the default (unset) that does. Item 2 says the lookup is unavailable with the knob unset; it takes FAKE_COUCH_LOOKUP=legacy. The Log says 154 native passes; the run at head shows 153/0/0.

## Round 2 — 2026-10-24T14:06:25-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Base fake restored at head: the new case and checktime autosave=true fail (exit 2); head fake gives 154 pass, 0 fail.
- BR-2 — addressed — Plan items 2 and 3 now match the fake's knob semantics; the Log's 154 matches the head run on nvim 0.11.7.

### Raised

- **BR-3** [Minor] `doc-claim-unverified` (kind: defect) The Log says only the new case fails on the base fake, but the base-fake run also failed checktime autosave=true
  This is the 2nd finding in family doc-claim-unverified. The rule: a Log claim about a test run states that run's outcome (its counts and which cases failed), not that a set of failures is exclusive. Running the base fake here also failed the racy checktime autosave=true case. No other instance in this window: the counts 25 and 154 and the 37/14/23 ms figures were checked.

## Open findings

- **BR-3** [Minor] `doc-claim-unverified` (kind: defect) The Log says only the new case fails on the base fake, but the base-fake run also failed checktime autosave=true
