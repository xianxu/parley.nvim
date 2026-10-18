---
gate: boundary-review
issue: 382
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d387f071-c04f-4f43-a8ed-5bcccd9a5cd5
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/329bdd0a4d33e763
            reviewed_head: 09ca797618c2e5807a1621f51ebceab46fe5f733
            slot: parley.nvim:4
            requested_at: "2026-10-18T06:11:06.171933Z"
          phase: finished
          pid: 55361
          started_at: "2026-10-18T06:11:06.27156Z"
          finished_at: "2026-10-18T06:13:45.624522Z"
          session_id: ee85d8e9-5e16-4db9-b5f1-f0d7eba939ec
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 09ca797618c2e5807a1621f51ebceab46fe5f733
        tracker_head: 1992984d6edac7753b6f6fc0e2ba8c1fcd4b20b2
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-17T23:10:40-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-17T23:10:40-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e7842fc47bd08937686ac4c0591121e874ae9785ca1d1094e8239355b2fce183
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 41035580
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-17T23:10:40-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
      "n": 1
      timestamp: "2026-10-17T23:13:46-07:00"
      dispatched: "2026-10-17T23:11:06-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
          detail: 'Family instances in this window: document_move.lua:994 and :1283 (no registry_options, so 15 s default) vs agentic_document.lua:380 (3x config_ms, 45 s, rule kept locally) and agentic_document.lua:618 (ms + 1000 margin kept locally). atlas/modes/session_sync.md:283 says document_registry owns the agentic deadlines; config.lua:500 and tests/helpers/arrival.lua describe a rename as getting three deadlines. Either derive both rename paths from one registry rename deadline helper, or narrow the atlas to say it owns the default deadline.'
          family: deadline-single-owner
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 09ca797618c2e5807a1621f51ebceab46fe5f733
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 3cd6c706-b875-41c1-9b5d-ac8454cc5e58
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4412e6b24f2344d9
            reviewed_head: 036cae07964a017a0491d22147a6c9fc8a1696bc
            slot: parley.nvim:4
            requested_at: "2026-10-18T06:15:48.398081Z"
          phase: finished
          pid: 46814
          started_at: "2026-10-18T06:15:48.493189Z"
          finished_at: "2026-10-18T06:16:59.847216Z"
          session_id: 2a56fec3-2cc5-49dc-aea3-c4d8a004159e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 036cae07964a017a0491d22147a6c9fc8a1696bc
        tracker_head: 8ed1555e94eeac6b7178fb1f4ceddf8950466b88
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-17T23:15:32-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-17T23:15:32-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: bc26205ea48594dfe8138dd3a06f67d1e9411337933849d6d6a992e8b1ee162c
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 41160888
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-17T23:15:32-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
        cuts:
            - dispatched: "2026-10-17T23:11:06-07:00"
              finalized: "2026-10-17T23:13:46-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-17T23:17:01-07:00"
      dispatched: "2026-10-17T23:15:48-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: document_registry.default_deadline_ms (3x for rename) now covers the native rename (agentic_document.lua:378) and both journaled renames (document_move.lua:994, :1284); the atlas and config.lua describe it accurately; spec 9/9 at head.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Minor
          title: The default_deadline_ms test stays green when request() stops using the helper
          detail: I reverted document_registry.lua:95 to config_ms("agentic_submit_timeout_ms") and document_registry_spec still passed 9/9, because the new test only checks the helper's arithmetic. Add a request()-level check, such as a rename against a fake slower than 1x but faster than 3x of a short submit deadline, and restore config inside a pcall.
          family: regression-test-pins-wiring
          round: 2
      recipe: fix-review
      isolation: fenced
      reviewed: 036cae07964a017a0491d22147a6c9fc8a1696bc
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 431461a9-4dc4-4b2c-a610-485c749b09a7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: fix-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/45242f9a35f2e5b1
            reviewed_head: 50cb93e46dc57bc449d2667e192049344968b039
            slot: parley.nvim:4
            requested_at: "2026-10-18T06:18:03.983788Z"
          phase: finished
          pid: 62956
          started_at: "2026-10-18T06:18:04.079916Z"
          finished_at: "2026-10-18T06:19:49.015207Z"
          session_id: 8f9f7110-b412-4a19-9b16-88838558b5e1
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 50cb93e46dc57bc449d2667e192049344968b039
        tracker_head: 98280587f156bf9d35998c97ef0c723e706464b7
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-17T23:17:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-17T23:17:48-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 4d30c4c619c9d80ccd98e737f3da1a0817c7630cf2297792f74289794be2d8e3
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 41252873
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-17T23:17:48-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
        cuts:
            - dispatched: "2026-10-17T23:11:06-07:00"
              finalized: "2026-10-17T23:13:46-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:15:48-07:00"
              finalized: "2026-10-17T23:17:01-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-17T23:20:01-07:00"
      dispatched: "2026-10-17T23:18:03-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: addressed
          note: The spec now sends a rename through request() with a 1000 ms submit deadline against a fake that holds renames 2 s, all inside a pcall that restores config and env. 9/9 at head; reverting document_registry.lua:95 to config_ms(...) fails that test (8/1), verified and restored.
          round: 3
      recipe: fix-review
      isolation: fenced
      reviewed: 50cb93e46dc57bc449d2667e192049344968b039
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 467ab042-6dd8-48f8-a14e-ff10ace53127
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: fix-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/6791dba6702d273d
            reviewed_head: ea4c01a60534f03ad762dc464494ac5b011f2490
            slot: parley.nvim:4
            requested_at: "2026-10-18T07:11:28.300484Z"
          phase: finished
          pid: 35607
          started_at: "2026-10-18T07:11:28.423951Z"
          finished_at: "2026-10-18T07:13:29.723168Z"
          session_id: dfb82984-8e54-4754-9f53-51c9fbc02056
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: ea4c01a60534f03ad762dc464494ac5b011f2490
        tracker_head: db2665dfd54425b0e6e7dc01c49dee1eea3cd49b
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-17T23:43:01-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-17T23:43:01-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: a8c8970d8fa200da0ad1a97a13ca87126c4482d2e2d7686ea85af669e4c5264a
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 41868756
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-17T23:43:01-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
            - attempt_id: 76a03c636a2702da736376846732e863
              slot: parley.nvim:4
              record_digest: d80b81b976e5c55d7e1bee3493aabda644d3147dc9729a4b7267c92fe88f8810
              start: "2026-10-18T06:22:02.13387Z"
              end: "2026-10-18T06:34:16.475381Z"
              queue_seconds: 734.341511
              raw_seconds: 734.341511
              exact: true
            - attempt_id: a3f3187684ab2144ed7e6e9c495bdd3a
              slot: parley.nvim:4
              record_digest: 6f4c41757cc2d9517e7a820d7e8190ee9a9a091ccbe77386279105f8f65bb8be
              start: "2026-10-18T06:38:57.435675Z"
              end: "2026-10-18T06:38:57.489725Z"
              queue_seconds: 0.05405
              raw_seconds: 0.05405
              exact: true
        cuts:
            - dispatched: "2026-10-17T23:11:06-07:00"
              finalized: "2026-10-17T23:13:46-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:15:48-07:00"
              finalized: "2026-10-17T23:17:01-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:18:03-07:00"
              finalized: "2026-10-17T23:20:01-07:00"
              finalizing: true
      "n": 4
      timestamp: "2026-10-18T00:13:30-07:00"
      dispatched: "2026-10-18T00:11:28-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Unchanged at head: document_registry.default_deadline_ms (3x submit for rename) still feeds request() via deadline_ms at document_registry.lua:80.'
          round: 4
        - id: BR-2
          disposition: addressed
          note: Unchanged at head; document_registry_spec passes 11/11 in an isolated run, including the request()-wiring rename case.
          round: 4
      findings:
        - kind: defect
          id: BR-3
          severity: Important
          title: Scope changed after close — run a full sdlc close
          detail: The post-close commits daf09f7b, d5bc1f90 and ea4c01a6 add behavior that no prior finding (BR-1, BR-2) asked for. The registry deadline now starts at spawn instead of enqueue; results carry new queued_ms/ran_ms/exit/stderr fields; and a new helper.start_deadline is applied in oauth.lua, tasker.lua (reconcile and attempt deadlines) and agentic_document.lua. The issue's Plan and Done-when don't record this; only Log entries were added. The narrow fix review cannot cover new cross-subsystem behavior, so it needs a full close review and a Revisions entry.
          family: scope-change-after-close
          round: 4
        - kind: defect
          id: BR-4
          severity: Minor
          title: cliproxy update-restart deadline is not routed through start_deadline despite the "every deadline" claim
          detail: cliproxy.lua:2393-2395 uses vim.defer_fn for a deadline whose expiry declares failure (answer with timeout=true), so it still measures from the loop's cached time. The Log says every such deadline now uses helper.start_deadline and does not list this site as an exclusion. Either route it through the helper or add it to the exclusions.
          family: deadline-clock-refresh-sweep
          round: 4
      recipe: fix-review
      isolation: fenced
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 66f2e43c-b9e4-4a46-a382-8a60aa152044
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: small-diff-review
            round: 5
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/31c394f525b7619a
            reviewed_head: af3d2f438ae2de062bcbb6fdb34b13c918450009
            slot: parley.nvim:4
            requested_at: "2026-10-18T07:44:35.807963Z"
          phase: finished
          pid: 1059
          started_at: "2026-10-18T07:44:36.04863Z"
          finished_at: "2026-10-18T07:57:33.48185Z"
          session_id: e669ef9f-af32-4f72-adcf-2cd205d8358a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: af3d2f438ae2de062bcbb6fdb34b13c918450009
        tracker_head: b462607e649213c635d635624d9e07652aadcbfb
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-18T00:16:19-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-18T00:16:19-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 886c4396b9a0b7297116ef2c1bb81e472540892d10d3dd9ae6b3388b3f3d9f93
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 42095449
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-18T00:16:19-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
            - attempt_id: 76a03c636a2702da736376846732e863
              slot: parley.nvim:4
              record_digest: d80b81b976e5c55d7e1bee3493aabda644d3147dc9729a4b7267c92fe88f8810
              start: "2026-10-18T06:22:02.13387Z"
              end: "2026-10-18T06:34:16.475381Z"
              queue_seconds: 734.341511
              raw_seconds: 734.341511
              exact: true
            - attempt_id: a3f3187684ab2144ed7e6e9c495bdd3a
              slot: parley.nvim:4
              record_digest: 6f4c41757cc2d9517e7a820d7e8190ee9a9a091ccbe77386279105f8f65bb8be
              start: "2026-10-18T06:38:57.435675Z"
              end: "2026-10-18T06:38:57.489725Z"
              queue_seconds: 0.05405
              raw_seconds: 0.05405
              exact: true
            - attempt_id: 8d0247e46bf442605ec9dc96a4042499
              slot: parley.nvim:4
              record_digest: 41fa5ad89ef926d55cd698be0a3e7a09311148451199c267bd0148aa4386d770
              start: "2026-10-18T06:43:38.865922Z"
              end: "2026-10-18T07:07:22.915441Z"
              queue_seconds: 1424.049519
              raw_seconds: 1424.049519
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 2.16095
        cuts:
            - dispatched: "2026-10-17T23:11:06-07:00"
              finalized: "2026-10-17T23:13:46-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:15:48-07:00"
              finalized: "2026-10-17T23:17:01-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:18:03-07:00"
              finalized: "2026-10-17T23:20:01-07:00"
              finalizing: true
            - dispatched: "2026-10-18T00:11:28-07:00"
              finalized: "2026-10-18T00:13:30-07:00"
              finalizing: false
      "n": 5
      timestamp: "2026-10-18T00:57:34-07:00"
      dispatched: "2026-10-18T00:44:35-07:00"
      agent: claude
      dispose:
        - id: BR-3
          disposition: addressed
          note: A Revisions entry (2026-10-18) records both post-close changes and their exclusions. This round reviewed the full window, base to head, including those changes.
          round: 5
        - id: BR-4
          disposition: addressed
          note: cliproxy.lua:2393 now calls helper.defer_deadline. Reverting defer_deadline's clock refresh fails start_deadline_spec (fired after 0 ms), so the helper the site now uses is pinned.
          round: 5
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: document_registry_spec asserts ran_ms >= 300 for a 300 ms libuv deadline and flakes under load
          detail: 'The "says why a request was refused" case at document_registry_spec.lua:487 requires late.ran_ms >= 300. libuv checks timer expiry against a millisecond-truncated loop clock, and ran_ms is a floored hrtime difference, so a correct deadline can report 299. Observed in 1 of 30 runs at 10x parallel load (ran_ms = 299, queued_ms = 0), and document_registry_spec also failed in one of two full integration runs. Rule: an elapsed-time assertion against a libuv deadline must allow the timer''s millisecond granularity, as start_deadline_spec does with >= 290. Instances in this window: this line (the only one at the boundary); start_deadline_spec.lua:20 and :43 already comply; document_registry_spec.lua:466 has ample margin.'
          family: elapsed-vs-deadline-tolerance
          round: 5
      recipe: small-diff-review
      isolation: fenced
      reviewed: af3d2f438ae2de062bcbb6fdb34b13c918450009
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d768cbb0-eaa6-4ed8-a81c-57c56da95ab2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: fix-review
            round: 6
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/afdc4f759a3779b2
            reviewed_head: 22100e5415f47db4e8f39b8734e254fd4053d3f0
            slot: parley.nvim:4
            requested_at: "2026-10-18T07:58:31.729744Z"
          phase: finished
          pid: 4770
          started_at: "2026-10-18T07:58:31.822589Z"
          finished_at: "2026-10-18T08:00:06.991802Z"
          session_id: 3d424228-e283-4f7e-90eb-55861b241fd8
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 22100e5415f47db4e8f39b8734e254fd4053d3f0
        tracker_head: b462607e649213c635d635624d9e07652aadcbfb
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-18T00:58:16-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-18T00:58:16-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c1967d4242a820f4ed3062d2112acbc0defbf661b2627841d0873d15def984a8
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 42170146
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-18T00:58:16-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
            - attempt_id: 76a03c636a2702da736376846732e863
              slot: parley.nvim:4
              record_digest: d80b81b976e5c55d7e1bee3493aabda644d3147dc9729a4b7267c92fe88f8810
              start: "2026-10-18T06:22:02.13387Z"
              end: "2026-10-18T06:34:16.475381Z"
              queue_seconds: 734.341511
              raw_seconds: 734.341511
              exact: true
            - attempt_id: a3f3187684ab2144ed7e6e9c495bdd3a
              slot: parley.nvim:4
              record_digest: 6f4c41757cc2d9517e7a820d7e8190ee9a9a091ccbe77386279105f8f65bb8be
              start: "2026-10-18T06:38:57.435675Z"
              end: "2026-10-18T06:38:57.489725Z"
              queue_seconds: 0.05405
              raw_seconds: 0.05405
              exact: true
            - attempt_id: 8d0247e46bf442605ec9dc96a4042499
              slot: parley.nvim:4
              record_digest: 41fa5ad89ef926d55cd698be0a3e7a09311148451199c267bd0148aa4386d770
              start: "2026-10-18T06:43:38.865922Z"
              end: "2026-10-18T07:07:22.915441Z"
              queue_seconds: 1424.049519
              raw_seconds: 1424.049519
              exact: true
            - attempt_id: e5aec6dc1f1ddfa745063b5ab9233ee7
              slot: parley.nvim:4
              record_digest: 24a433560174ce0868802d7a70c832a04d4c7e7784e1df615249763812fc0f4f
              start: "2026-10-18T07:16:29.290893Z"
              end: "2026-10-18T07:41:31.576904Z"
              queue_seconds: 1502.286011
              raw_seconds: 1502.286011
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 7.6532333333333336
        cuts:
            - dispatched: "2026-10-17T23:11:06-07:00"
              finalized: "2026-10-17T23:13:46-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:15:48-07:00"
              finalized: "2026-10-17T23:17:01-07:00"
              finalizing: true
            - dispatched: "2026-10-17T23:18:03-07:00"
              finalized: "2026-10-17T23:20:01-07:00"
              finalizing: true
            - dispatched: "2026-10-18T00:11:28-07:00"
              finalized: "2026-10-18T00:13:30-07:00"
              finalizing: false
            - dispatched: "2026-10-18T00:44:35-07:00"
              finalized: "2026-10-18T00:57:34-07:00"
              finalizing: true
      "n": 6
      timestamp: "2026-10-18T01:00:07-07:00"
      dispatched: "2026-10-18T00:58:31-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: 'document_registry_spec.lua:139 now asserts ran_ms >= 290 with the reason stated, matching start_deadline_spec. The sweep checked: line 116 has about 600 ms of margin. Spec passed 11/11 on 3 runs.'
          round: 6
      recipe: fix-review
      isolation: fenced
      reviewed: 22100e5415f47db4e8f39b8734e254fd4053d3f0
      blocked: false
---

# Gate ledger — parley.nvim#382 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T23:13:46-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `deadline-single-owner` (kind: defect) Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
  Family instances in this window: document_move.lua:994 and :1283 (no registry_options, so 15 s default) vs agentic_document.lua:380 (3x config_ms, 45 s, rule kept locally) and agentic_document.lua:618 (ms + 1000 margin kept locally). atlas/modes/session_sync.md:283 says document_registry owns the agentic deadlines; config.lua:500 and tests/helpers/arrival.lua describe a rename as getting three deadlines. Either derive both rename paths from one registry rename deadline helper, or narrow the atlas to say it owns the default deadline.

## Round 2 — 2026-10-17T23:17:01-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — document_registry.default_deadline_ms (3x for rename) now covers the native rename (agentic_document.lua:378) and both journaled renames (document_move.lua:994, :1284); the atlas and config.lua describe it accurately; spec 9/9 at head.

### Raised

- **BR-2** [Minor] `regression-test-pins-wiring` (kind: defect) The default_deadline_ms test stays green when request() stops using the helper
  I reverted document_registry.lua:95 to config_ms("agentic_submit_timeout_ms") and document_registry_spec still passed 9/9, because the new test only checks the helper's arithmetic. Add a request()-level check, such as a rename against a fake slower than 1x but faster than 3x of a short submit deadline, and restore config inside a pcall.

## Round 3 — 2026-10-17T23:20:01-07:00 (claude) — passed

### Disposed

- BR-2 — addressed — The spec now sends a rename through request() with a 1000 ms submit deadline against a fake that holds renames 2 s, all inside a pcall that restores config and env. 9/9 at head; reverting document_registry.lua:95 to config_ms(...) fails that test (8/1), verified and restored.

## Round 4 — 2026-10-18T00:13:30-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Unchanged at head: document_registry.default_deadline_ms (3x submit for rename) still feeds request() via deadline_ms at document_registry.lua:80.
- BR-2 — addressed — Unchanged at head; document_registry_spec passes 11/11 in an isolated run, including the request()-wiring rename case.

### Raised

- **BR-3** [Important] `scope-change-after-close` (kind: defect) Scope changed after close — run a full sdlc close
  The post-close commits daf09f7b, d5bc1f90 and ea4c01a6 add behavior that no prior finding (BR-1, BR-2) asked for. The registry deadline now starts at spawn instead of enqueue; results carry new queued_ms/ran_ms/exit/stderr fields; and a new helper.start_deadline is applied in oauth.lua, tasker.lua (reconcile and attempt deadlines) and agentic_document.lua. The issue's Plan and Done-when don't record this; only Log entries were added. The narrow fix review cannot cover new cross-subsystem behavior, so it needs a full close review and a Revisions entry.
- **BR-4** [Minor] `deadline-clock-refresh-sweep` (kind: defect) cliproxy update-restart deadline is not routed through start_deadline despite the "every deadline" claim
  cliproxy.lua:2393-2395 uses vim.defer_fn for a deadline whose expiry declares failure (answer with timeout=true), so it still measures from the loop's cached time. The Log says every such deadline now uses helper.start_deadline and does not list this site as an exclusion. Either route it through the helper or add it to the exclusions.

## Round 5 — 2026-10-18T00:57:34-07:00 (claude) — passed

### Disposed

- BR-3 — addressed — A Revisions entry (2026-10-18) records both post-close changes and their exclusions. This round reviewed the full window, base to head, including those changes.
- BR-4 — addressed — cliproxy.lua:2393 now calls helper.defer_deadline. Reverting defer_deadline's clock refresh fails start_deadline_spec (fired after 0 ms), so the helper the site now uses is pinned.

### Raised

- **BR-5** [Important] `elapsed-vs-deadline-tolerance` (kind: defect) document_registry_spec asserts ran_ms >= 300 for a 300 ms libuv deadline and flakes under load
  The "says why a request was refused" case at document_registry_spec.lua:487 requires late.ran_ms >= 300. libuv checks timer expiry against a millisecond-truncated loop clock, and ran_ms is a floored hrtime difference, so a correct deadline can report 299. Observed in 1 of 30 runs at 10x parallel load (ran_ms = 299, queued_ms = 0), and document_registry_spec also failed in one of two full integration runs. Rule: an elapsed-time assertion against a libuv deadline must allow the timer's millisecond granularity, as start_deadline_spec does with >= 290. Instances in this window: this line (the only one at the boundary); start_deadline_spec.lua:20 and :43 already comply; document_registry_spec.lua:466 has ample margin.

## Round 6 — 2026-10-18T01:00:07-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — document_registry_spec.lua:139 now asserts ran_ms >= 290 with the reason stated, matching start_deadline_spec. The sweep checked: line 116 has about 600 ms of margin. Spec passed 11/11 on 3 runs.

## Open findings

(none — every finding has been disposed)
