---
gate: boundary-review
issue: 362
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a54f134a-81d2-436e-9624-04f06e3c31fa
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/25a90caf93d724e6
            reviewed_head: 70ec26d438345fa93d0519fb1a8d115e812245af
            slot: parley.nvim:1
            requested_at: "2026-10-17T01:11:06.561409Z"
          phase: finished
          pid: 44706
          started_at: "2026-10-17T01:11:06.669296Z"
          finished_at: "2026-10-17T01:12:51.667835Z"
          session_id: 01a14769-9fd0-79f0-82ca-8113e8801376
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 70ec26d438345fa93d0519fb1a8d115e812245af
        tracker_head: f5ab523f97d17b6919184e257ef51478683b727b
        branch_point: 75c795b448fbe7fdd8c38785f2c7c64001ef91c4
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T18:10:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T18:10:53-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 2b618f6bd97dd5719f19d7e3fd037ff68ecfa16f8b698ff58c3b185fdf905b8b
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 27864300
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T18:10:53-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T18:10:53-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
      "n": 1
      timestamp: "2026-10-16T18:12:54-07:00"
      dispatched: "2026-10-16T18:11:06-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: The imported collaboration contract requires operations the local adapter cannot perform
          detail: "lua/parley/skills/review/collaboration-modes.md:72 requires every discussion question to create a side doc; discussion is now the default even without frontmatter (line 29). Thus an ordinary local \U0001F916[why?] request can no longer be answered consistently: local-adapter.md:10-16 permits only one propose_edits call, and lua/parley/skill_invoke.lua:567-569 forcibly binds that call to the submitted artifact. No available write operation can create the required side doc. Removing the marker and inserting its prescribed link would leave a nonexistent target; answering inline violates the new contract.\nThe complete affected capability family in this window is discussion question/decision-note/nested side-doc creation (lines 72, 105-107, 155-157), chat answer creation and follow-up writes (128-138), cross-document approval folds (93, 202-218), and retry/relink/orphan discovery (205-222). Chat additionally requires a change baseline that local-adapter.md:18-20 explicitly lacks, while marker-free chat submissions are skipped by review/init.lua's existing precheck. These instructions are also embedded in generated SKILL.md. Reconcile the Parley-owned local compatibility policy with these capabilities, document the supported behavior, and add regression coverage for default questions and explicit collaboration/chat handling. ARCH-PURPOSE: successful concatenation does not establish a usable local contract."
          family: prompt-adapter-capability-contract
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Done-when omits the newly required old-export notice
          detail: workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md:33-36 only requires tests and synchronization for an export containing collaboration modes. The revision at lines 133-135 adds a required notice when the member is absent, implemented in scripts/sync-review-protocol.py:156-158. The entire uncovered acceptance family is old-v1 success plus the notice during normal sync and --check; tests/unit/review_protocol_export_test.py:296-305 already exercises both. Update Done-when to require those outcomes explicitly.
          family: acceptance-contract-coverage
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4adbe885-05fc-4eea-906b-65301257cfb7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/7f95cbb77a770a55
            reviewed_head: 5789ac0f26392fb45a8c9121f323b3ddbc980da5
            slot: parley.nvim:1
            requested_at: "2026-10-17T02:26:03.487465Z"
          phase: finished
          pid: 34637
          started_at: "2026-10-17T02:26:03.592884Z"
          finished_at: "2026-10-17T02:28:12.455932Z"
          session_id: 01a147ae-3e2c-77b3-8503-bec981baaf24
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5789ac0f26392fb45a8c9121f323b3ddbc980da5
        tracker_head: cd510dea6c4cbba24ac0713db0b22403fad138ad
        branch_point: 75c795b448fbe7fdd8c38785f2c7c64001ef91c4
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T19:25:47-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T19:25:47-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 9be85226135a22aa1db168c0a036d5602a681f206da53b25c4dc5dfbc2e9956f
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 29867225
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T19:25:47-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T19:25:47-07:00"
            - harness: codex
              id: 01a1478c-d17c-7823-9d2b-ffd0b50bb137
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 48644a4bd898c99f9e4215cbacd3f384979caae54edab9b4603222d1cddd6cb5
              started: "2026-10-17T01:49:33.55Z"
              spawned: true
              bytes: 709976
              windows:
                - start: "2026-10-17T01:49:33.55Z"
                  end: "2026-10-16T19:25:47-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
        cuts:
            - dispatched: "2026-10-16T18:11:06-07:00"
              finalized: "2026-10-16T18:12:54-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T19:28:14-07:00"
      dispatched: "2026-10-16T19:26:03-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'The local-adapter override and reachable admission/proposal guards correct the original mismatch for recognized declarations; removing those fixes produces regression failures. However, collaboration_value.lua:128-173 recognizes only column-zero field lines. Frontmatter containing either `  collaboration-mode: chat` or `{collaboration-mode: chat}` returns no value and no error. Direct execution confirms resolve marks the body editable discussion and validate_edits permits replacing its text. Thus the promised chat protection remains incomplete. For family prompt-adapter-capability-contract, state and enforce the general rule: distinguish genuinely absent routing from unsupported or malformed declarations; decode supported representations and visibly refuse unsupported ones. Enumerate declaration representations and add parser, admission, and real-write regression coverage. ARCH-PURPOSE, ARCH-SECURE.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: The pinned issue diff adds Done-when lines 37-39 requiring old-v1 sync and --check success, with a notice from each command. This matches scripts/sync-review-protocol.py:156-158 and test_old_v1_cli_reports_absent_collaboration_modes at tests/unit/review_protocol_export_test.py:296-305, which exercises both commands and passed. This is a prose-only acceptance correction.
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9de6d1e1-4936-452a-8312-88f6fca44412
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f07e4555abd9f3f6
            reviewed_head: 21b756db6e71597fed48ada97c69c5e301f4058d
            slot: parley.nvim:1
            requested_at: "2026-10-17T03:22:45.42142Z"
          phase: finished
          pid: 45565
          started_at: "2026-10-17T03:22:45.543142Z"
          finished_at: "2026-10-17T03:25:32.506179Z"
          session_id: 01a147e2-26a9-7b02-899e-185422223da4
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 21b756db6e71597fed48ada97c69c5e301f4058d
        tracker_head: c6dcebbc8ce96368e5cf8b3a4f3ecef3584f1992
        branch_point: 75c795b448fbe7fdd8c38785f2c7c64001ef91c4
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T20:22:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T20:22:30-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 306931385fe6c3b3535a9f34d78cdeaab47d33fb200f98a17f6aaec1f578cb36
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 31134246
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T20:22:30-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T20:22:30-07:00"
            - harness: codex
              id: 01a1478c-d17c-7823-9d2b-ffd0b50bb137
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9a788b17b422bb0a3c5a013979a33327d8f2c816679da1c96735cfd4f5c22742
              started: "2026-10-17T01:49:33.55Z"
              spawned: true
              bytes: 856648
              windows:
                - start: "2026-10-17T01:49:33.55Z"
                  end: "2026-10-16T20:22:30-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
        cuts:
            - dispatched: "2026-10-16T18:11:06-07:00"
              finalized: "2026-10-16T18:12:54-07:00"
              finalizing: false
            - dispatched: "2026-10-16T19:26:03-07:00"
              finalized: "2026-10-16T19:28:14-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T20:25:34-07:00"
      dispatched: "2026-10-16T20:22:45-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: local-adapter.md:10-18 overrides incompatible imported operations; admission and invocation-owned proposal validation enforce chat protection. All 64 invocation tests pass at head. Restoring the pre-correction parser in a disposable copy produces 12 regression failures.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Issue Done when lines 37-39 explicitly require old-v1 sync and --check notices. test_old_v1_cli_reports_absent_collaboration_modes verifies both commands; all 16 Python contract tests pass.
          round: 3
      findings:
        - kind: defect
          id: BR-3
          severity: Important
          title: Frontmatter comment scanning causes quadratic editor stalls
          detail: 'ARCH-CONSTRAINTS: lua/parley/skills/review/collaboration_value.lua:13 copies and searches the entire preceding prefix for every character, even in unrelated metadata. Parsing {''---'', ''notes: ''..string.rep(''a'', n), ''---'', ''body''} under LuaJIT took 0.279/1.110/4.471 seconds for 5/10/20 KB. review_send.lua:66 and review/init.lua:590 call this synchronously, so a submission can repeat several seconds of editor blocking before generation. Track the preceding non-whitespace character incrementally, inspect sibling scanners for repeated-prefix work, and add representative scaling coverage.'
          family: synchronous-input-work-bounds
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 80b24dbe-71d9-4da3-bf5c-bcde1c017d0e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d756f455484f1e33
            reviewed_head: 4e50304904ca03049b21675361ae8a62c053f1d8
            slot: parley.nvim:1
            requested_at: "2026-10-17T04:41:30.256322Z"
          phase: finished
          pid: 8276
          started_at: "2026-10-17T04:41:30.35248Z"
          finished_at: "2026-10-17T04:43:19.684208Z"
          session_id: 01a1482a-3edb-73e3-b76c-700d5706fd37
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4e50304904ca03049b21675361ae8a62c053f1d8
        tracker_head: 3745aab13916d280ccce680af05af48eb41487ad
        branch_point: 75c795b448fbe7fdd8c38785f2c7c64001ef91c4
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T21:41:15-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T21:41:15-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 0599def1d742ca2de267f78901964e7c5c0db7a4c777ed5781425297dc8b9f1b
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 33742178
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T21:41:15-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T21:41:15-07:00"
            - harness: codex
              id: 01a1478c-d17c-7823-9d2b-ffd0b50bb137
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9a788b17b422bb0a3c5a013979a33327d8f2c816679da1c96735cfd4f5c22742
              started: "2026-10-17T01:49:33.55Z"
              spawned: true
              bytes: 856648
              windows:
                - start: "2026-10-17T01:49:33.55Z"
                  end: "2026-10-16T21:41:15-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
        cuts:
            - dispatched: "2026-10-16T18:11:06-07:00"
              finalized: "2026-10-16T18:12:54-07:00"
              finalizing: false
            - dispatched: "2026-10-16T19:26:03-07:00"
              finalized: "2026-10-16T19:28:14-07:00"
              finalizing: false
            - dispatched: "2026-10-16T20:22:45-07:00"
              finalized: "2026-10-16T20:25:34-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-16T21:43:22-07:00"
      dispatched: "2026-10-16T21:41:30-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The local adapter explicitly overrides imported routing; admission and invocation-owned protection enforce that policy. The mapped review suite and all 64 real-tool invocation cases pass, including declaration refusals, protected chat bytes, and multiple-proposal rejection.
          round: 4
        - id: BR-2
          disposition: addressed
          note: Issue Done when lines 37–39 explicitly require successful old-v1 sync and --check with the absent-modes notice. test_old_v1_cli_reports_absent_collaboration_modes verifies both commands; all 16 Python contracts pass.
          round: 4
        - id: BR-3
          disposition: not-addressed
          note: 'ARCH-CONSTRAINTS / ARCH-PURPOSE, family synchronous-input-work-bounds: parser fixes are regression-proven, but collaboration.lua:6 retains unanchored whitespace trimming and :59/:65 retain backtracking heading patterns. On pinned HEAD under LuaJIT, resolve({''# A''..string.rep('' '',n)..''Z'',''body''}) takes 0.235/0.952/3.780 CPU seconds at 5/10/20 KB; a quoted chat heading assignment takes 0.148/0.591/2.346 seconds. For that 20 KB assignment, parse alone takes 0.001084 seconds while resolve takes 2.356312 seconds. These paths remain synchronous in review_send.lua:66 and review/init.lua:590. Complete the existing family sweep across full routing admission, replace backtracking edge/heading scans with bounded scans, and add resolver-level scaling regressions.'
          round: 4
      recipe: milestone-review
      isolation: fenced
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6c12ed95-2031-44cb-956e-af5c0538ebd1
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: milestone-review
            round: 5
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1d8df91334122d7c
            reviewed_head: 8be9bfde97b0618704bcdd4c035550c30bea6791
            slot: parley.nvim:1
            requested_at: "2026-10-17T05:58:36.49782Z"
          phase: finished
          pid: 84970
          started_at: "2026-10-17T05:58:36.592257Z"
          finished_at: "2026-10-17T06:00:41.910969Z"
          session_id: 01a14870-d61a-75a0-872e-eda2614c18d0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8be9bfde97b0618704bcdd4c035550c30bea6791
        tracker_head: e98daed6130eed7f98a7e84dcd2e4fa7e9b7e88e
        branch_point: 3e055bc1e3c11defa75743c020f2698204fb7bcc
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T22:58:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T22:58:21-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: fa1960d0b947f19bb19468f0cfa93c4e672ca27f870bd56567cac69ea3e1442c
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 35361757
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T22:58:21-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T22:58:21-07:00"
            - harness: codex
              id: 01a1478c-d17c-7823-9d2b-ffd0b50bb137
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 9a788b17b422bb0a3c5a013979a33327d8f2c816679da1c96735cfd4f5c22742
              started: "2026-10-17T01:49:33.55Z"
              spawned: true
              bytes: 856648
              windows:
                - start: "2026-10-17T01:49:33.55Z"
                  end: "2026-10-16T22:58:21-07:00"
        excluded_brain_sessions: 2
        excluded_brain_minutes: 15.784566666666667
        cuts:
            - dispatched: "2026-10-16T18:11:06-07:00"
              finalized: "2026-10-16T18:12:54-07:00"
              finalizing: false
            - dispatched: "2026-10-16T19:26:03-07:00"
              finalized: "2026-10-16T19:28:14-07:00"
              finalizing: false
            - dispatched: "2026-10-16T20:22:45-07:00"
              finalized: "2026-10-16T20:25:34-07:00"
              finalizing: false
            - dispatched: "2026-10-16T21:41:30-07:00"
              finalized: "2026-10-16T21:43:22-07:00"
              finalizing: false
      "n": 5
      timestamp: "2026-10-16T23:00:42-07:00"
      dispatched: "2026-10-16T22:58:36-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The local adapter override and invocation-owned protection remain effective; review and skill-system suites pass, including protected-chat and unsupported-declaration cases.
          round: 5
        - id: BR-2
          disposition: addressed
          note: Done when explicitly requires old-v1 sync and --check success with notices; the corresponding real-CLI regression passes.
          round: 5
        - id: BR-3
          disposition: addressed
          note: 'ARCH-CONSTRAINTS / ARCH-PURPOSE: bounded scans now cover complete routing admission. The resolver regressions at tests/unit/review_collaboration_spec.lua:76 and :88 fail with the previous-round resolver at 3.10/6.37 CPU seconds and pass at HEAD at 0.004/0.001 seconds. The production 5/10/20 KB heading and assignment paths also remain below 0.002 seconds.'
          round: 5
      recipe: milestone-review
      isolation: fenced
      reviewed: 8be9bfde97b0618704bcdd4c035550c30bea6791
      blocked: false
---

# Gate ledger — parley.nvim#362 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T18:12:54-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `prompt-adapter-capability-contract` (kind: defect) The imported collaboration contract requires operations the local adapter cannot perform
  lua/parley/skills/review/collaboration-modes.md:72 requires every discussion question to create a side doc; discussion is now the default even without frontmatter (line 29). Thus an ordinary local 🤖[why?] request can no longer be answered consistently: local-adapter.md:10-16 permits only one propose_edits call, and lua/parley/skill_invoke.lua:567-569 forcibly binds that call to the submitted artifact. No available write operation can create the required side doc. Removing the marker and inserting its prescribed link would leave a nonexistent target; answering inline violates the new contract.
  The complete affected capability family in this window is discussion question/decision-note/nested side-doc creation (lines 72, 105-107, 155-157), chat answer creation and follow-up writes (128-138), cross-document approval folds (93, 202-218), and retry/relink/orphan discovery (205-222). Chat additionally requires a change baseline that local-adapter.md:18-20 explicitly lacks, while marker-free chat submissions are skipped by review/init.lua's existing precheck. These instructions are also embedded in generated SKILL.md. Reconcile the Parley-owned local compatibility policy with these capabilities, document the supported behavior, and add regression coverage for default questions and explicit collaboration/chat handling. ARCH-PURPOSE: successful concatenation does not establish a usable local contract.
- **BR-2** [Important] `acceptance-contract-coverage` (kind: defect) Done-when omits the newly required old-export notice
  workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md:33-36 only requires tests and synchronization for an export containing collaboration modes. The revision at lines 133-135 adds a required notice when the member is absent, implemented in scripts/sync-review-protocol.py:156-158. The entire uncovered acceptance family is old-v1 success plus the notice during normal sync and --check; tests/unit/review_protocol_export_test.py:296-305 already exercises both. Update Done-when to require those outcomes explicitly.

## Round 2 — 2026-10-16T19:28:14-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The local-adapter override and reachable admission/proposal guards correct the original mismatch for recognized declarations; removing those fixes produces regression failures. However, collaboration_value.lua:128-173 recognizes only column-zero field lines. Frontmatter containing either `  collaboration-mode: chat` or `{collaboration-mode: chat}` returns no value and no error. Direct execution confirms resolve marks the body editable discussion and validate_edits permits replacing its text. Thus the promised chat protection remains incomplete. For family prompt-adapter-capability-contract, state and enforce the general rule: distinguish genuinely absent routing from unsupported or malformed declarations; decode supported representations and visibly refuse unsupported ones. Enumerate declaration representations and add parser, admission, and real-write regression coverage. ARCH-PURPOSE, ARCH-SECURE.
- BR-2 — addressed — The pinned issue diff adds Done-when lines 37-39 requiring old-v1 sync and --check success, with a notice from each command. This matches scripts/sync-review-protocol.py:156-158 and test_old_v1_cli_reports_absent_collaboration_modes at tests/unit/review_protocol_export_test.py:296-305, which exercises both commands and passed. This is a prose-only acceptance correction.

## Round 3 — 2026-10-16T20:25:34-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — local-adapter.md:10-18 overrides incompatible imported operations; admission and invocation-owned proposal validation enforce chat protection. All 64 invocation tests pass at head. Restoring the pre-correction parser in a disposable copy produces 12 regression failures.
- BR-2 — addressed — Issue Done when lines 37-39 explicitly require old-v1 sync and --check notices. test_old_v1_cli_reports_absent_collaboration_modes verifies both commands; all 16 Python contract tests pass.

### Raised

- **BR-3** [Important] `synchronous-input-work-bounds` (kind: defect) Frontmatter comment scanning causes quadratic editor stalls
  ARCH-CONSTRAINTS: lua/parley/skills/review/collaboration_value.lua:13 copies and searches the entire preceding prefix for every character, even in unrelated metadata. Parsing {'---', 'notes: '..string.rep('a', n), '---', 'body'} under LuaJIT took 0.279/1.110/4.471 seconds for 5/10/20 KB. review_send.lua:66 and review/init.lua:590 call this synchronously, so a submission can repeat several seconds of editor blocking before generation. Track the preceding non-whitespace character incrementally, inspect sibling scanners for repeated-prefix work, and add representative scaling coverage.

## Round 4 — 2026-10-16T21:43:22-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — The local adapter explicitly overrides imported routing; admission and invocation-owned protection enforce that policy. The mapped review suite and all 64 real-tool invocation cases pass, including declaration refusals, protected chat bytes, and multiple-proposal rejection.
- BR-2 — addressed — Issue Done when lines 37–39 explicitly require successful old-v1 sync and --check with the absent-modes notice. test_old_v1_cli_reports_absent_collaboration_modes verifies both commands; all 16 Python contracts pass.
- BR-3 — not-addressed — ARCH-CONSTRAINTS / ARCH-PURPOSE, family synchronous-input-work-bounds: parser fixes are regression-proven, but collaboration.lua:6 retains unanchored whitespace trimming and :59/:65 retain backtracking heading patterns. On pinned HEAD under LuaJIT, resolve({'# A'..string.rep(' ',n)..'Z','body'}) takes 0.235/0.952/3.780 CPU seconds at 5/10/20 KB; a quoted chat heading assignment takes 0.148/0.591/2.346 seconds. For that 20 KB assignment, parse alone takes 0.001084 seconds while resolve takes 2.356312 seconds. These paths remain synchronous in review_send.lua:66 and review/init.lua:590. Complete the existing family sweep across full routing admission, replace backtracking edge/heading scans with bounded scans, and add resolver-level scaling regressions.

## Round 5 — 2026-10-16T23:00:42-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — The local adapter override and invocation-owned protection remain effective; review and skill-system suites pass, including protected-chat and unsupported-declaration cases.
- BR-2 — addressed — Done when explicitly requires old-v1 sync and --check success with notices; the corresponding real-CLI regression passes.
- BR-3 — addressed — ARCH-CONSTRAINTS / ARCH-PURPOSE: bounded scans now cover complete routing admission. The resolver regressions at tests/unit/review_collaboration_spec.lua:76 and :88 fail with the previous-round resolver at 3.10/6.37 CPU seconds and pass at HEAD at 0.004/0.001 seconds. The production 5/10/20 KB heading and assignment paths also remain below 0.002 seconds.

## Open findings

(none — every finding has been disposed)
