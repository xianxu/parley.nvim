---
gate: boundary-review
issue: 442
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 79c33dd9-198d-46b3-b45c-ac4f214b3886
            repository: github.com/xianxu/parley.nvim
            issue_id: "000442"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/0ee573c2b1bc26f8
            reviewed_head: 3572f43c679938b9cd6ec6bd54f7fcd1a9bee5af
            slot: parley.nvim:1
            requested_at: "2026-10-25T02:22:51.710607Z"
          phase: finished
          pid: 27869
          started_at: "2026-10-25T02:22:51.835938Z"
          finished_at: "2026-10-25T02:24:55.903533Z"
          session_id: 72621a11-9e05-4e8d-a45a-9e47108b43f6
          outcome: returned
      actual_inputs:
        version: 4
        method: active-time-v3-branch-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3572f43c679938b9cd6ec6bd54f7fcd1a9bee5af
        tracker_head: c87bcdba60c6040d05d2017ace1dcfb5fc0041d1
        branch_point: daa8b598ad9977926ed5aac0bb3258eb428c8000
        since: "2026-10-24T11:57:59-07:00"
        until: "2026-10-24T18:31:58-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-24T11:57:59-07:00"
              end: "2026-10-24T18:31:58-07:00"
              began: "2026-10-24T11:57:59-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 4a0bc1072364a83a0c94dc6dee2abc418418116d2f02195063391a536876191c
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 20534755
              windows:
                - start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
              dispatch_windows:
                - start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-24T18:31:58-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.08931666666666667
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: 3572f43c679938b9cd6ec6bd54f7fcd1a9bee5af
              branch: 000442-native-lost-reply-release-case-flakes-under-load
              digest: cfef23c86b1cc35cbba8ddbe9f23250c677af20814392e939074d1f40a5ba2aa
              bytes: 165115
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source_index: 0
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source_index: 0
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source_index: 0
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T18:31:58-07:00"
                  kind: branch
      "n": 1
      timestamp: "2026-10-24T19:24:57-07:00"
      dispatched: "2026-10-24T19:22:51-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: A retry cannot reconcile an unconfirmed turn's release that landed but lost its reply
          detail: |-
            In session_sync.lua at 1111-1124, turn_lock reads the on-disk lock. When a release for an unconfirmed acquire landed but lost its reply, the lock is gone. operator_proof(nil) then returns nil, and release_if_baseline returns false before its `retrying and bytes == nil` branch, so that branch can never run for this turn kind.
            The admission therefore stays `unconfirmed` and keeps the old token. The winbar keeps saying "Couch unreachable", there is no refresh or idle restart, and the next i re-acquires with the released token. A confirmed turn does reconcile in the same situation.
            Fix: carry the expected bytes into retry_release, or reuse the bytes captured on the first attempt when `retrying` is set. Add a test: an unconfirmed acquire with DELAY=2, then slow_next_release("after").
            Same class, other sites: the comment at 1120, atlas/modes/session_sync.md:131 ("released the same way"), and the plan item "through the bounded retry".
          family: unconfirmed-turn-release-retry
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: One native-spec site still uses mode i plus a vim.schedule barrier as proof that admission finished
          detail: |-
            In tests/integration/session_sync_native_spec.lua at 854-860, the test runs keys("iX"), waits for mode i, then uses a vim.schedule barrier before reading the buffer line, modifiable and the lock. The admission waits in vim.system():wait(), which runs the event loop, so the scheduled barrier can fire mid-admission. This is the same mechanism the new insert() comment describes.
            Fix: wait on the insert_admitted counter, as insert() does.
            Enumerated all mode-i waits: 446 and 605 already wait for admission, 1217 and 1414 run detached, and at 1435 the restore needs no acquire. Only 855 remains.
          family: mode-i-is-not-admission
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Two Done-when clauses were met only under a TL waiver, and the issue does not revise them
          detail: |-
            Done-when requires 20 reps per nvim under the same capped load. Delivered: 10 reps per nvim (20 runs per case) at fleet load, with no spinners and no dd loop.
            Done-when requires both failures to be explained with evidence. The second failure was explained only by a deterministic probe that reproduces the symptom; it was never observed under the original load.
            The TL approved both, but only in the Log. Add a Revisions entry or edit Done-when so the close record matches what was delivered.
          family: done-when-clause-unmet
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: turn_lock repeats release_owned's identity and turn-token ownership check
          detail: The check `proof.ID == s.identity.ID and proof.Turn == acquire_token` appears at session_sync.lua:1117 and at 328 (negated). A shared owns_turn(s, proof) helper would keep one source of truth (ARCH-DRY).
          family: ownership-predicate-single-source
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 322ebfa9-f117-412d-bced-92de24863701
            repository: github.com/xianxu/parley.nvim
            issue_id: "000442"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/39ea353c9b03d153
            reviewed_head: a0d2a98c09d47756fb512319445420042be4ecdd
            slot: parley.nvim:1
            requested_at: "2026-10-25T05:00:21.75489Z"
          phase: finished
          pid: 84550
          started_at: "2026-10-25T05:00:21.843515Z"
          finished_at: "2026-10-25T05:16:44.220032Z"
          session_id: 2d9c13b4-7490-4ea0-913a-e4e35f2f5df4
          outcome: returned
      actual_inputs:
        version: 4
        method: active-time-v3-branch-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: a0d2a98c09d47756fb512319445420042be4ecdd
        tracker_head: d31ea7cb13771fed76b4e18d06eed569f713a0af
        branch_point: daa8b598ad9977926ed5aac0bb3258eb428c8000
        since: "2026-10-24T11:57:59-07:00"
        until: "2026-10-24T20:33:40-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-24T11:57:59-07:00"
              end: "2026-10-24T20:33:40-07:00"
              began: "2026-10-24T11:57:59-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 0d16f1ad8a61063c5fbc0a87731dc711e662c35acee7a4e4b3ebc3b15375ac2c
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 21666760
              windows:
                - start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
              dispatch_windows:
                - start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-24T20:33:40-07:00"
        queue_waits:
            - attempt_id: 39b09cf73a089e91fc2f5263799b2389
              slot: parley.nvim:1
              record_digest: 45db07f0ccee05083cdf984025c6f73bf8d5e8ad50d453f73ef2c112baee6fb3
              start: "2026-10-25T02:12:28.306906Z"
              end: "2026-10-25T02:12:31.083451Z"
              queue_seconds: 2.776545
              raw_seconds: 2.776545
              exact: true
            - attempt_id: aa83b3cc3539703ba4a333e76eaeda3b
              slot: parley.nvim:1
              record_digest: 41da6300c81731f7d2e131f4134d9b732b82a617db9a62894411ae933abc21ce
              start: "2026-10-25T02:43:24.676143Z"
              end: "2026-10-25T03:19:14.922399Z"
              queue_seconds: 2150.246256
              raw_seconds: 2150.246256
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.179116666666667
        cuts:
            - dispatched: "2026-10-24T19:22:51-07:00"
              finalized: "2026-10-24T19:24:57-07:00"
              finalizing: false
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: a0d2a98c09d47756fb512319445420042be4ecdd
              branch: 000442-native-lost-reply-release-case-flakes-under-load
              digest: 127853854d4831926b52e18da4b7f58d6045d3747af1ee5c972948c82921cf55
              bytes: 165715
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source_index: 0
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source_index: 0
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source_index: 0
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T20:33:40-07:00"
                  kind: branch
      "n": 2
      timestamp: "2026-10-24T22:16:46-07:00"
      dispatched: "2026-10-24T22:00:21-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: retry_release carries expected bytes; reverting `retried or` turns the new case red at spec:762, restored it is green (make test-spec SPEC=modes/session_sync rc=0).
          round: 2
        - id: BR-2
          disposition: addressed
          note: spec:874 now uses insert("X") plus a typed-text wait; one sibling outside the named site remains, raised as a new family finding.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The Revisions section records the scope add and both Done-when evidence changes; the Log also shows the capped-load clause met at d1a60d14.
          round: 2
        - id: BR-4
          disposition: addressed
          note: of_turn(s, proof) at session_sync.lua:324 is used by both release_owned and turn_lock.
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: Refused-retry final entry still uses keys("i") plus a vim.schedule barrier as admission proof (spec:337-341)
          detail: 'This is the 2nd finding in family mode-i-is-not-admission. Rule: in an attached, registered case, every keys("i...") followed by an admission-effect assertion either goes through insert() or waits for text typed after the i to arrive; mode i or a schedule barrier is never admission proof. Enumeration of raw keys("i") sites: 164, 230, 276, 316, 549, 670, 777, 824 and 864 wait for typed text; 607 waits on local_i; 181, 1231, 1428 and 1449 are detached; 886 is unregistered; 168 asserts only a pre-existing lock (benign); 337 is the only violation, where it reads modifiable mid-admission. Fix: use insert() at 337, and optionally add a tests/arch grep guard against keys("i followed by a vim.schedule barrier.'
          family: mode-i-is-not-admission
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2659fbc2-92c5-492f-bf5f-6e8823fbe4bb
            repository: github.com/xianxu/parley.nvim
            issue_id: "000442"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/3d4741d5fe7545cf
            reviewed_head: 5a566e541bb361b042503268dc5d0a7e5001186b
            slot: parley.nvim:1
            requested_at: "2026-10-25T06:15:56.18398Z"
          phase: finished
          pid: 16597
          started_at: "2026-10-25T06:15:56.288279Z"
          finished_at: "2026-10-25T06:17:19.299254Z"
          session_id: 50f2248d-2888-4178-bb8c-812e0ffa6425
          outcome: returned
      actual_inputs:
        version: 4
        method: active-time-v3-branch-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5a566e541bb361b042503268dc5d0a7e5001186b
        tracker_head: d31ea7cb13771fed76b4e18d06eed569f713a0af
        branch_point: daa8b598ad9977926ed5aac0bb3258eb428c8000
        since: "2026-10-24T11:57:59-07:00"
        until: "2026-10-24T22:26:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-24T11:57:59-07:00"
              end: "2026-10-24T22:26:13-07:00"
              began: "2026-10-24T11:57:59-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: cf1626b9cd907b0aa461cff0bbe2152d2a731c3ff49775f75b895a2e355afebe
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 21970311
              windows:
                - start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
              dispatch_windows:
                - start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-24T22:26:13-07:00"
        queue_waits:
            - attempt_id: 39b09cf73a089e91fc2f5263799b2389
              slot: parley.nvim:1
              record_digest: 45db07f0ccee05083cdf984025c6f73bf8d5e8ad50d453f73ef2c112baee6fb3
              start: "2026-10-25T02:12:28.306906Z"
              end: "2026-10-25T02:12:31.083451Z"
              queue_seconds: 2.776545
              raw_seconds: 2.776545
              exact: true
            - attempt_id: aa83b3cc3539703ba4a333e76eaeda3b
              slot: parley.nvim:1
              record_digest: 41da6300c81731f7d2e131f4134d9b732b82a617db9a62894411ae933abc21ce
              start: "2026-10-25T02:43:24.676143Z"
              end: "2026-10-25T03:19:14.922399Z"
              queue_seconds: 2150.246256
              raw_seconds: 2150.246256
              exact: true
            - attempt_id: 0b36f31efd7f0d4bc298268f6faa73a4
              slot: parley.nvim:1
              record_digest: be9eb833a4bf8c5daf69dc28d8966eb74979a17b6efd6004ce2f03bf8848fbb8
              start: "2026-10-25T03:46:06.42772Z"
              end: "2026-10-25T04:51:09.506447Z"
              queue_seconds: 3903.078727
              raw_seconds: 3903.078727
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.179116666666667
        cuts:
            - dispatched: "2026-10-24T19:22:51-07:00"
              finalized: "2026-10-24T19:24:57-07:00"
              finalizing: false
            - dispatched: "2026-10-24T22:00:21-07:00"
              finalized: "2026-10-24T22:16:46-07:00"
              finalizing: false
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: 5a566e541bb361b042503268dc5d0a7e5001186b
              branch: 000442-native-lost-reply-release-case-flakes-under-load
              digest: bc39c5efc60d27d87ecec94ca26b2eada4ab00be4b2a7447a52ffe3568a9aed4
              bytes: 165921
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source_index: 0
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source_index: 0
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source_index: 0
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-24T11:57:59-07:00"
                  end: "2026-10-25T00:42:34Z"
                  branch: 000427-native-undo-redo-autosave-case-sees-remote-view-unavailable
                  kind: foreign-branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:42:34Z"
                  end: "2026-10-25T00:43:24Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:43:24Z"
                  end: "2026-10-24T22:26:13-07:00"
                  kind: branch
      "n": 3
      timestamp: "2026-10-24T23:17:20-07:00"
      dispatched: "2026-10-24T23:15:56-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-5
          disposition: addressed
          note: Both :168 and :336 now use insert(). The arch guard copied into nvim -l flags exactly 168 and 337 on a0d2a98c and finds nothing at head (16 entries).
          round: 3
      findings:
        - kind: defect
          id: BR-6
          severity: Minor
          title: No recorded integration run of session_sync_native_spec after the BR-5 edits to :168 and :336
          detail: The Log records only the arch-guard control after 5a566e54. Run make SPEC=modes/session_sync on 0.11.7 and 0.12.5 and log it. The only instances in this window are the two insert() swaps at :168 and :336.
          family: post-fix-run-evidence
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: 5a566e541bb361b042503268dc5d0a7e5001186b
      blocked: false
---

# Gate ledger — parley.nvim#442 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-24T19:24:57-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `unconfirmed-turn-release-retry` (kind: defect) A retry cannot reconcile an unconfirmed turn's release that landed but lost its reply
  In session_sync.lua at 1111-1124, turn_lock reads the on-disk lock. When a release for an unconfirmed acquire landed but lost its reply, the lock is gone. operator_proof(nil) then returns nil, and release_if_baseline returns false before its `retrying and bytes == nil` branch, so that branch can never run for this turn kind.
  The admission therefore stays `unconfirmed` and keeps the old token. The winbar keeps saying "Couch unreachable", there is no refresh or idle restart, and the next i re-acquires with the released token. A confirmed turn does reconcile in the same situation.
  Fix: carry the expected bytes into retry_release, or reuse the bytes captured on the first attempt when `retrying` is set. Add a test: an unconfirmed acquire with DELAY=2, then slow_next_release("after").
  Same class, other sites: the comment at 1120, atlas/modes/session_sync.md:131 ("released the same way"), and the plan item "through the bounded retry".
- **BR-2** [Important] `mode-i-is-not-admission` (kind: defect) One native-spec site still uses mode i plus a vim.schedule barrier as proof that admission finished
  In tests/integration/session_sync_native_spec.lua at 854-860, the test runs keys("iX"), waits for mode i, then uses a vim.schedule barrier before reading the buffer line, modifiable and the lock. The admission waits in vim.system():wait(), which runs the event loop, so the scheduled barrier can fire mid-admission. This is the same mechanism the new insert() comment describes.
  Fix: wait on the insert_admitted counter, as insert() does.
  Enumerated all mode-i waits: 446 and 605 already wait for admission, 1217 and 1414 run detached, and at 1435 the restore needs no acquire. Only 855 remains.
- **BR-3** [Important] `done-when-clause-unmet` (kind: defect) Two Done-when clauses were met only under a TL waiver, and the issue does not revise them
  Done-when requires 20 reps per nvim under the same capped load. Delivered: 10 reps per nvim (20 runs per case) at fleet load, with no spinners and no dd loop.
  Done-when requires both failures to be explained with evidence. The second failure was explained only by a deterministic probe that reproduces the symptom; it was never observed under the original load.
  The TL approved both, but only in the Log. Add a Revisions entry or edit Done-when so the close record matches what was delivered.
- **BR-4** [Minor] `ownership-predicate-single-source` (kind: defect) turn_lock repeats release_owned's identity and turn-token ownership check
  The check `proof.ID == s.identity.ID and proof.Turn == acquire_token` appears at session_sync.lua:1117 and at 328 (negated). A shared owns_turn(s, proof) helper would keep one source of truth (ARCH-DRY).

## Round 2 — 2026-10-24T22:16:46-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — retry_release carries expected bytes; reverting `retried or` turns the new case red at spec:762, restored it is green (make test-spec SPEC=modes/session_sync rc=0).
- BR-2 — addressed — spec:874 now uses insert("X") plus a typed-text wait; one sibling outside the named site remains, raised as a new family finding.
- BR-3 — addressed — The Revisions section records the scope add and both Done-when evidence changes; the Log also shows the capped-load clause met at d1a60d14.
- BR-4 — addressed — of_turn(s, proof) at session_sync.lua:324 is used by both release_owned and turn_lock.

### Raised

- **BR-5** [Important] `mode-i-is-not-admission` (kind: defect) Refused-retry final entry still uses keys("i") plus a vim.schedule barrier as admission proof (spec:337-341)
  This is the 2nd finding in family mode-i-is-not-admission. Rule: in an attached, registered case, every keys("i...") followed by an admission-effect assertion either goes through insert() or waits for text typed after the i to arrive; mode i or a schedule barrier is never admission proof. Enumeration of raw keys("i") sites: 164, 230, 276, 316, 549, 670, 777, 824 and 864 wait for typed text; 607 waits on local_i; 181, 1231, 1428 and 1449 are detached; 886 is unregistered; 168 asserts only a pre-existing lock (benign); 337 is the only violation, where it reads modifiable mid-admission. Fix: use insert() at 337, and optionally add a tests/arch grep guard against keys("i followed by a vim.schedule barrier.

## Round 3 — 2026-10-24T23:17:20-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — Both :168 and :336 now use insert(). The arch guard copied into nvim -l flags exactly 168 and 337 on a0d2a98c and finds nothing at head (16 entries).

### Raised

- **BR-6** [Minor] `post-fix-run-evidence` (kind: defect) No recorded integration run of session_sync_native_spec after the BR-5 edits to :168 and :336
  The Log records only the arch-guard control after 5a566e54. Run make SPEC=modes/session_sync on 0.11.7 and 0.12.5 and log it. The only instances in this window are the two insert() swaps at :168 and :336.

## Open findings

- **BR-6** [Minor] `post-fix-run-evidence` (kind: defect) No recorded integration run of session_sync_native_spec after the BR-5 edits to :168 and :336
