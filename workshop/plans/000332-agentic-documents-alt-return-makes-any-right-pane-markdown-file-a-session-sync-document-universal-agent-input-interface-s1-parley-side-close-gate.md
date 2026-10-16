---
gate: boundary-review
issue: 332
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d005ac77-a86e-4347-b2ad-c31155e637f7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/62e82e6231b05a0c
            reviewed_head: c3b815092d3044a516fb0914f69a95614cdc069e
            slot: parley.nvim:2
            requested_at: "2026-10-16T01:14:21.24309Z"
          phase: finished
          pid: 37967
          started_at: "2026-10-16T01:14:21.619261Z"
          finished_at: "2026-10-16T01:17:38.290309Z"
          session_id: 01a14246-3e92-7491-ac90-0ed30b7f1e45
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c3b815092d3044a516fb0914f69a95614cdc069e
        tracker_head: 16b5bc00e4d2b91b82830a72f16c7ca9c4736d0a
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T13:07:57-07:00"
        until: "2026-10-15T18:13:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T13:07:57-07:00"
              end: "2026-10-15T18:13:55-07:00"
              began: "2026-10-15T13:07:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d088e5fd2ac4bfb59de9994bec60961722ad2924cfba09f6afaedb0f6a148883
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 41536415
              windows:
                - start: "2026-10-15T13:07:57-07:00"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1412e-8523-7fa2-9e8c-d8873b1348df
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 55d32eabe6849de7420d62370c1ee8cbdffa559d7544e690fbb279d03bf6fcb1
              started: "2026-10-15T20:08:50.417Z"
              spawned: true
              bytes: 562266
              windows:
                - start: "2026-10-15T20:08:50.417Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1412e-a904-7710-88fe-3f3326bacbcc
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e19cce2151caca3c6a35df764819278eb98007792e2be7960f124d75267c2922
              started: "2026-10-15T20:08:59.629Z"
              spawned: true
              bytes: 1012259
              windows:
                - start: "2026-10-15T20:08:59.629Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 0a52ac8e8d17b31dddcd9fa12c53d6c59414c4f769fdd84edbbe32e78c039069
              started: "2026-10-15T20:27:17Z"
              spawned: false
              bytes: 662693
              windows:
                - start: "2026-10-15T20:27:17Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 863c26a3a60d78138d7d4d9e026dc076d3dcd52ebf4d6fd91eb39cd79f6e26f5
              started: "2026-10-15T20:34:40.952Z"
              spawned: false
              bytes: 443654
              windows:
                - start: "2026-10-15T20:34:40.952Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14148-4d6b-7bc1-a650-2ac9c3c9c103
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: e408e478d4696e1747739db1fb465c979f69c4b263451e6ada34ac2395ff57eb
              started: "2026-10-15T20:37:00.683Z"
              spawned: false
              bytes: 431233
              windows:
                - start: "2026-10-15T20:37:00.683Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14148-d1e2-7301-9d8e-167ed3bc3b48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d706bfd9766ca0500d3ad296a41a7ee61746e7dfe1db8060b2344292e176d0d9
              started: "2026-10-15T20:37:34.757Z"
              spawned: false
              bytes: 458095
              windows:
                - start: "2026-10-15T20:37:34.757Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414a-f880-7dc2-b5fa-55ab37d93fa5
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: ae49424b7bd974ded7aec0df4f02ae4f7afd12b097cdf0a5cb6f7f4f0030350e
              started: "2026-10-15T20:39:54.868Z"
              spawned: true
              bytes: 3585300
              windows:
                - start: "2026-10-15T20:39:54.868Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414b-1aae-7ea1-955b-65ac06abf8d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: f79fa3e5773c745bd6d37cb14c93d6c8f372f5ebf53fedb94e32ec3998d41764
              started: "2026-10-15T20:40:03.611Z"
              spawned: true
              bytes: 1814060
              windows:
                - start: "2026-10-15T20:40:03.611Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414b-3f7d-78f1-8ff5-cf30539ca92f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 0519dff3151393e2d0153286ae2fdf7c3cc9d04a55fe2727949a88e4a4634fc0
              started: "2026-10-15T20:40:13.046Z"
              spawned: true
              bytes: 3670814
              windows:
                - start: "2026-10-15T20:40:13.046Z"
                  end: "2026-10-15T18:13:55-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.029516666666666667
      "n": 1
      timestamp: "2026-10-15T18:17:38-07:00"
      dispatched: "2026-10-15T18:14:21-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Native rename treats unresolved membership as plain and strands registration
          detail: 'lua/parley/agentic_document.lua:554-557 returns from BufFilePre when neither coordinator nor legacy identity is attached, including while initial lookup is pending or unavailable. Reproduced with an existing registration and delayed initial lookup: native :saveas succeeded, NEW became plain with no identity or edit lock, and independent registry queries reported OLD registered / NEW absent. ARCH-PURPOSE and ARCH-ORDER: require confirmed absence before allowing the plain rename path; resolve membership or refuse only the migration when membership is unknown. Add controlled-order regressions for native rename during probing and unavailable admission.'
          family: membership-before-migration
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: Lookup completion during buffer unload permanently strands the operation on reopen
          detail: 'lua/parley/agentic_document.lua:185 discards callbacks when the buffer is unloaded, but line 315 detaches only on BufWipeout. Reproduced by holding initial lookup, running :bdelete, completing lookup while unloaded, then reopening: the controller remained probing with its completed lookup still recorded, and subsequent submit could neither requery nor submit. ARCH-ORDER and ARCH-FUNERAL: invalidate the buffer incarnation and close owned requests/leases on unload, or explicitly model suspended completion and restart admission on reload; preserve uncertain mutation/journal recovery. Add delayed-completion unload/reopen tests across lookup, mutation and migration.'
          family: async-buffer-lifetime
          round: 1
        - kind: defect
          id: BR-3
          severity: Critical
          title: Core concepts declares not_chat PURE despite editor and filesystem dependencies
          detail: workshop/plans/000332-agentic-documents-plan.md:38 labels not_chat PURE, but lua/parley/init.lua:1845 resolves configured chat roots and line 1856 reads buffer contents when supplied_lines is omitted. Its existing tests/integration/not_chat_spec.lua creates directories, writes files and constructs buffers. This contradicts the required Core concepts classification and ARCH-PURE. Promote this wrapper to INTEGRATION, or extract a value-only classifier and classify/test that separately; record the correction under Revisions.
          family: core-concept-purity-contract
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 573a6836-0896-4182-985f-202f9ccb5fff
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f20b0868a22e44d9
            reviewed_head: 2fee90247e1fef6cddb9402f80b828cbbb29ba45
            slot: parley.nvim:2
            requested_at: "2026-10-16T02:00:24.7537Z"
          phase: finished
          pid: 6635
          started_at: "2026-10-16T02:00:25.015296Z"
          finished_at: "2026-10-16T02:05:09.978746Z"
          session_id: 01a14270-6835-7b32-ac76-31c411029d5d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2fee90247e1fef6cddb9402f80b828cbbb29ba45
        tracker_head: 803cd288813e9b51749b17f37e9a277b25749fc3
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T13:07:57-07:00"
        until: "2026-10-15T18:59:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T13:07:57-07:00"
              end: "2026-10-15T18:59:38-07:00"
              began: "2026-10-15T13:07:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: ebb3dbed8dbbf7c15c5686da1ba69cf9b9c357370f526fdc7dedda876e247c3b
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 44071794
              windows:
                - start: "2026-10-15T13:07:57-07:00"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1412e-8523-7fa2-9e8c-d8873b1348df
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 55d32eabe6849de7420d62370c1ee8cbdffa559d7544e690fbb279d03bf6fcb1
              started: "2026-10-15T20:08:50.417Z"
              spawned: true
              bytes: 562266
              windows:
                - start: "2026-10-15T20:08:50.417Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1412e-a904-7710-88fe-3f3326bacbcc
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e19cce2151caca3c6a35df764819278eb98007792e2be7960f124d75267c2922
              started: "2026-10-15T20:08:59.629Z"
              spawned: true
              bytes: 1012259
              windows:
                - start: "2026-10-15T20:08:59.629Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 0a52ac8e8d17b31dddcd9fa12c53d6c59414c4f769fdd84edbbe32e78c039069
              started: "2026-10-15T20:27:17Z"
              spawned: false
              bytes: 662693
              windows:
                - start: "2026-10-15T20:27:17Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 863c26a3a60d78138d7d4d9e026dc076d3dcd52ebf4d6fd91eb39cd79f6e26f5
              started: "2026-10-15T20:34:40.952Z"
              spawned: false
              bytes: 443654
              windows:
                - start: "2026-10-15T20:34:40.952Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a14148-4d6b-7bc1-a650-2ac9c3c9c103
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: e408e478d4696e1747739db1fb465c979f69c4b263451e6ada34ac2395ff57eb
              started: "2026-10-15T20:37:00.683Z"
              spawned: false
              bytes: 431233
              windows:
                - start: "2026-10-15T20:37:00.683Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a14148-d1e2-7301-9d8e-167ed3bc3b48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d706bfd9766ca0500d3ad296a41a7ee61746e7dfe1db8060b2344292e176d0d9
              started: "2026-10-15T20:37:34.757Z"
              spawned: false
              bytes: 458095
              windows:
                - start: "2026-10-15T20:37:34.757Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1414a-f880-7dc2-b5fa-55ab37d93fa5
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: da138dcad941f05a1b1f6f9f70a8a97a9ca4b82bfa42e55aa1a70316283847c8
              started: "2026-10-15T20:39:54.868Z"
              spawned: true
              bytes: 4008905
              windows:
                - start: "2026-10-15T20:39:54.868Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1414b-1aae-7ea1-955b-65ac06abf8d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: f79fa3e5773c745bd6d37cb14c93d6c8f372f5ebf53fedb94e32ec3998d41764
              started: "2026-10-15T20:40:03.611Z"
              spawned: true
              bytes: 1814060
              windows:
                - start: "2026-10-15T20:40:03.611Z"
                  end: "2026-10-15T18:59:38-07:00"
            - harness: codex
              id: 01a1414b-3f7d-78f1-8ff5-cf30539ca92f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: b02baa44cbefc9362a50cd1ce250a165174260c13b4357a9694bede5be835a96
              started: "2026-10-15T20:40:13.046Z"
              spawned: true
              bytes: 4441012
              windows:
                - start: "2026-10-15T20:40:13.046Z"
                  end: "2026-10-15T18:59:38-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.029516666666666667
        cuts:
            - dispatched: "2026-10-15T18:14:21-07:00"
              finalized: "2026-10-15T18:17:38-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T19:05:11-07:00"
      dispatched: "2026-10-15T19:00:24-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Native and public migration preflight now require confirmed membership and recheck activity after waits. Controlled regressions in agentic_document_spec.lua:595 onward pass at HEAD and fail with the pre-fix coordinator.
          round: 2
        - id: BR-2
          disposition: addressed
          note: True BufUnload retires the incarnation, cancels requests and releases migration leases; managed rereads defer completions. Lifetime regressions cover lookup, register, rename and send across unload/reopen; restoring the pre-fix coordinator produces five failures.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Plan line 38 now classifies not_chat as INTEGRATION, with the correction explained under Revisions at line 252. This matches configured-root resolution and optional buffer reads in init.lua:1845-1856 and its existing integration tests.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Plan still promises lease-file cleanup that the implementation deliberately omits
          detail: workshop/plans/000332-agentic-documents-plan.md:113 promises opportunistic cleanup after forgetting/completed recovery. document_lease.lua:76-79 only closes descriptors, and atlas/modes/session_sync.md:170-172 explicitly documents permanent allocation without automatic GC. Under ARCH-FUNERAL, align the Plan with the implemented 4096-entry bound and overflow refusal.
          family: plan-runtime-traceability
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 2fee90247e1fef6cddb9402f80b828cbbb29ba45
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e5631d20-6320-4ebe-bb3c-a743d96a875b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/46f447859467b623
            reviewed_head: 67638184a0c31d67c6673edd3884c19fe45bb75f
            slot: parley.nvim:2
            requested_at: "2026-10-16T05:01:31.061459Z"
          phase: finished
          pid: 86660
          started_at: "2026-10-16T05:01:31.144503Z"
          finished_at: "2026-10-16T05:04:04.622349Z"
          session_id: 01a14316-3564-7483-be1b-d4d6f20dbd9a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 67638184a0c31d67c6673edd3884c19fe45bb75f
        tracker_head: b95922db0ea603cf0846b78e5e59a0474b5e07a9
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T13:07:57-07:00"
        until: "2026-10-15T22:01:14-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T13:07:57-07:00"
              end: "2026-10-15T22:01:14-07:00"
              began: "2026-10-15T13:07:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: efef1e3aaff6afe697a5496e017d3c3f592d3cd01305ec3740c76aa3b00b6c0d
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 45746877
              windows:
                - start: "2026-10-15T13:07:57-07:00"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1412e-8523-7fa2-9e8c-d8873b1348df
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 55d32eabe6849de7420d62370c1ee8cbdffa559d7544e690fbb279d03bf6fcb1
              started: "2026-10-15T20:08:50.417Z"
              spawned: true
              bytes: 562266
              windows:
                - start: "2026-10-15T20:08:50.417Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1412e-a904-7710-88fe-3f3326bacbcc
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e19cce2151caca3c6a35df764819278eb98007792e2be7960f124d75267c2922
              started: "2026-10-15T20:08:59.629Z"
              spawned: true
              bytes: 1012259
              windows:
                - start: "2026-10-15T20:08:59.629Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 0a52ac8e8d17b31dddcd9fa12c53d6c59414c4f769fdd84edbbe32e78c039069
              started: "2026-10-15T20:27:17Z"
              spawned: false
              bytes: 662693
              windows:
                - start: "2026-10-15T20:27:17Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 863c26a3a60d78138d7d4d9e026dc076d3dcd52ebf4d6fd91eb39cd79f6e26f5
              started: "2026-10-15T20:34:40.952Z"
              spawned: false
              bytes: 443654
              windows:
                - start: "2026-10-15T20:34:40.952Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a14148-4d6b-7bc1-a650-2ac9c3c9c103
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: e408e478d4696e1747739db1fb465c979f69c4b263451e6ada34ac2395ff57eb
              started: "2026-10-15T20:37:00.683Z"
              spawned: false
              bytes: 431233
              windows:
                - start: "2026-10-15T20:37:00.683Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a14148-d1e2-7301-9d8e-167ed3bc3b48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d706bfd9766ca0500d3ad296a41a7ee61746e7dfe1db8060b2344292e176d0d9
              started: "2026-10-15T20:37:34.757Z"
              spawned: false
              bytes: 458095
              windows:
                - start: "2026-10-15T20:37:34.757Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1414a-f880-7dc2-b5fa-55ab37d93fa5
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: d72b70f61dbe88787e1ffa6ff6f62da8097ba0e88cf107cda61b2425d97d4bdc
              started: "2026-10-15T20:39:54.868Z"
              spawned: true
              bytes: 4946974
              windows:
                - start: "2026-10-15T20:39:54.868Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1414b-1aae-7ea1-955b-65ac06abf8d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: f79fa3e5773c745bd6d37cb14c93d6c8f372f5ebf53fedb94e32ec3998d41764
              started: "2026-10-15T20:40:03.611Z"
              spawned: true
              bytes: 1814060
              windows:
                - start: "2026-10-15T20:40:03.611Z"
                  end: "2026-10-15T22:01:14-07:00"
            - harness: codex
              id: 01a1414b-3f7d-78f1-8ff5-cf30539ca92f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: b02baa44cbefc9362a50cd1ce250a165174260c13b4357a9694bede5be835a96
              started: "2026-10-15T20:40:13.046Z"
              spawned: true
              bytes: 4441012
              windows:
                - start: "2026-10-15T20:40:13.046Z"
                  end: "2026-10-15T22:01:14-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.059416666666666
        cuts:
            - dispatched: "2026-10-15T18:14:21-07:00"
              finalized: "2026-10-15T18:17:38-07:00"
              finalizing: false
            - dispatched: "2026-10-15T19:00:24-07:00"
              finalized: "2026-10-15T19:05:11-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-15T22:04:05-07:00"
      dispatched: "2026-10-15T22:01:31-07:00"
      agent: codex
      dispose:
        - id: BR-4
          disposition: addressed
          note: Plan line 113 now explicitly documents permanent lease allocation, no automatic GC, and the 4096-entry bound with overflow refusal. This matches document_lease.lua and atlas/modes/session_sync.md:170-172; the pinned correction is prose-only.
          round: 3
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: Buffer round trips restore another buffer's original window options
          detail: lua/parley/document_band.lua:59 retires the previous buffer's record after the window already displays the next buffer; restore() therefore applies that previous record's baseline to the current buffer. A native headless A→B→A probe with distinct original options and identical rendered bands restored A to "original B" / "StatusLine:IncSearch", instead of "original A" / "StatusLine:Search". Preserve ownership and original values per window/buffer pair, or restore before leaving the owning buffer. Add round-trip coverage with distinct originals; the existing handoff test uses identical originals and misses this defect. ARCH-ORDER.
          family: window-option-ownership
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2e8f23c6-e615-4439-973e-7b09c462e527
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/45fb772892ccf261
            reviewed_head: 0c4552064aa5a005038317f90d5f87c3a2a45613
            slot: parley.nvim:2
            requested_at: "2026-10-16T05:15:15.155018Z"
          phase: finished
          pid: 80081
          started_at: "2026-10-16T05:15:15.246213Z"
          finished_at: "2026-10-16T05:18:11.955377Z"
          session_id: 01a14322-c897-7783-a97a-0affd43fd853
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0c4552064aa5a005038317f90d5f87c3a2a45613
        tracker_head: b95922db0ea603cf0846b78e5e59a0474b5e07a9
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T13:07:57-07:00"
        until: "2026-10-15T22:15:02-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T13:07:57-07:00"
              end: "2026-10-15T22:15:02-07:00"
              began: "2026-10-15T13:07:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: dcd84e93f5a80231332c696cefdf22f346539892490bbfb8382c499c4036c8ff
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 46404989
              windows:
                - start: "2026-10-15T13:07:57-07:00"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1412e-8523-7fa2-9e8c-d8873b1348df
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 55d32eabe6849de7420d62370c1ee8cbdffa559d7544e690fbb279d03bf6fcb1
              started: "2026-10-15T20:08:50.417Z"
              spawned: true
              bytes: 562266
              windows:
                - start: "2026-10-15T20:08:50.417Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1412e-a904-7710-88fe-3f3326bacbcc
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e19cce2151caca3c6a35df764819278eb98007792e2be7960f124d75267c2922
              started: "2026-10-15T20:08:59.629Z"
              spawned: true
              bytes: 1012259
              windows:
                - start: "2026-10-15T20:08:59.629Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 0a52ac8e8d17b31dddcd9fa12c53d6c59414c4f769fdd84edbbe32e78c039069
              started: "2026-10-15T20:27:17Z"
              spawned: false
              bytes: 662693
              windows:
                - start: "2026-10-15T20:27:17Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 863c26a3a60d78138d7d4d9e026dc076d3dcd52ebf4d6fd91eb39cd79f6e26f5
              started: "2026-10-15T20:34:40.952Z"
              spawned: false
              bytes: 443654
              windows:
                - start: "2026-10-15T20:34:40.952Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a14148-4d6b-7bc1-a650-2ac9c3c9c103
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: e408e478d4696e1747739db1fb465c979f69c4b263451e6ada34ac2395ff57eb
              started: "2026-10-15T20:37:00.683Z"
              spawned: false
              bytes: 431233
              windows:
                - start: "2026-10-15T20:37:00.683Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a14148-d1e2-7301-9d8e-167ed3bc3b48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d706bfd9766ca0500d3ad296a41a7ee61746e7dfe1db8060b2344292e176d0d9
              started: "2026-10-15T20:37:34.757Z"
              spawned: false
              bytes: 458095
              windows:
                - start: "2026-10-15T20:37:34.757Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1414a-f880-7dc2-b5fa-55ab37d93fa5
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: c7b00f58ccec27dff92300b62808220ac59147cfa6f41584bf82d1850b83ab42
              started: "2026-10-15T20:39:54.868Z"
              spawned: true
              bytes: 5035846
              windows:
                - start: "2026-10-15T20:39:54.868Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1414b-1aae-7ea1-955b-65ac06abf8d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: f79fa3e5773c745bd6d37cb14c93d6c8f372f5ebf53fedb94e32ec3998d41764
              started: "2026-10-15T20:40:03.611Z"
              spawned: true
              bytes: 1814060
              windows:
                - start: "2026-10-15T20:40:03.611Z"
                  end: "2026-10-15T22:15:02-07:00"
            - harness: codex
              id: 01a1414b-3f7d-78f1-8ff5-cf30539ca92f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: b02baa44cbefc9362a50cd1ce250a165174260c13b4357a9694bede5be835a96
              started: "2026-10-15T20:40:13.046Z"
              spawned: true
              bytes: 4441012
              windows:
                - start: "2026-10-15T20:40:13.046Z"
                  end: "2026-10-15T22:15:02-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.059416666666666
        cuts:
            - dispatched: "2026-10-15T18:14:21-07:00"
              finalized: "2026-10-15T18:17:38-07:00"
              finalizing: false
            - dispatched: "2026-10-15T19:00:24-07:00"
              finalized: "2026-10-15T19:05:11-07:00"
              finalizing: true
            - dispatched: "2026-10-15T22:01:31-07:00"
              finalized: "2026-10-15T22:04:05-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-15T22:18:14-07:00"
      dispatched: "2026-10-15T22:15:15-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Native and public move preflight confirms OLD membership and rechecks busy state after yielding; admission and owned-move regressions pass.
          round: 4
        - id: BR-2
          disposition: addressed
          note: True unload retires the incarnation and lease; managed reads defer completions until reconciliation. All 10 buffer-lifetime regressions pass.
          round: 4
        - id: BR-3
          disposition: addressed
          note: The plan Core concepts table correctly classifies not_chat as INTEGRATION; init.lua retains the editor/filesystem-dependent wrapper.
          round: 4
        - id: BR-4
          disposition: addressed
          note: The plan explicitly states that lease files remain permanently allocated, automatic GC is absent, and allocation is capped at 4096 IDs per namespace; document_lease.lua implements that contract.
          round: 4
        - id: BR-5
          disposition: addressed
          note: document_band.lua preserves restoration proofs per window/buffer pair and checks buffer ownership before restoring. Both distinct-baseline round-trip tests pass at HEAD and fail when only the renderer is replaced with its pre-fix version, reproducing B's originals being restored into A.
          round: 4
      recipe: milestone-review
      isolation: fenced
      reviewed: 0c4552064aa5a005038317f90d5f87c3a2a45613
      blocked: false
---

# Gate ledger — parley.nvim#332 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T18:17:38-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `membership-before-migration` (kind: defect) Native rename treats unresolved membership as plain and strands registration
  lua/parley/agentic_document.lua:554-557 returns from BufFilePre when neither coordinator nor legacy identity is attached, including while initial lookup is pending or unavailable. Reproduced with an existing registration and delayed initial lookup: native :saveas succeeded, NEW became plain with no identity or edit lock, and independent registry queries reported OLD registered / NEW absent. ARCH-PURPOSE and ARCH-ORDER: require confirmed absence before allowing the plain rename path; resolve membership or refuse only the migration when membership is unknown. Add controlled-order regressions for native rename during probing and unavailable admission.
- **BR-2** [Critical] `async-buffer-lifetime` (kind: defect) Lookup completion during buffer unload permanently strands the operation on reopen
  lua/parley/agentic_document.lua:185 discards callbacks when the buffer is unloaded, but line 315 detaches only on BufWipeout. Reproduced by holding initial lookup, running :bdelete, completing lookup while unloaded, then reopening: the controller remained probing with its completed lookup still recorded, and subsequent submit could neither requery nor submit. ARCH-ORDER and ARCH-FUNERAL: invalidate the buffer incarnation and close owned requests/leases on unload, or explicitly model suspended completion and restart admission on reload; preserve uncertain mutation/journal recovery. Add delayed-completion unload/reopen tests across lookup, mutation and migration.
- **BR-3** [Critical] `core-concept-purity-contract` (kind: defect) Core concepts declares not_chat PURE despite editor and filesystem dependencies
  workshop/plans/000332-agentic-documents-plan.md:38 labels not_chat PURE, but lua/parley/init.lua:1845 resolves configured chat roots and line 1856 reads buffer contents when supplied_lines is omitted. Its existing tests/integration/not_chat_spec.lua creates directories, writes files and constructs buffers. This contradicts the required Core concepts classification and ARCH-PURE. Promote this wrapper to INTEGRATION, or extract a value-only classifier and classify/test that separately; record the correction under Revisions.

## Round 2 — 2026-10-15T19:05:11-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Native and public migration preflight now require confirmed membership and recheck activity after waits. Controlled regressions in agentic_document_spec.lua:595 onward pass at HEAD and fail with the pre-fix coordinator.
- BR-2 — addressed — True BufUnload retires the incarnation, cancels requests and releases migration leases; managed rereads defer completions. Lifetime regressions cover lookup, register, rename and send across unload/reopen; restoring the pre-fix coordinator produces five failures.
- BR-3 — addressed — Plan line 38 now classifies not_chat as INTEGRATION, with the correction explained under Revisions at line 252. This matches configured-root resolution and optional buffer reads in init.lua:1845-1856 and its existing integration tests.

### Raised

- **BR-4** [Minor] `plan-runtime-traceability` (kind: defect) Plan still promises lease-file cleanup that the implementation deliberately omits
  workshop/plans/000332-agentic-documents-plan.md:113 promises opportunistic cleanup after forgetting/completed recovery. document_lease.lua:76-79 only closes descriptors, and atlas/modes/session_sync.md:170-172 explicitly documents permanent allocation without automatic GC. Under ARCH-FUNERAL, align the Plan with the implemented 4096-entry bound and overflow refusal.

## Round 3 — 2026-10-15T22:04:05-07:00 (codex) — BLOCKED

### Disposed

- BR-4 — addressed — Plan line 113 now explicitly documents permanent lease allocation, no automatic GC, and the 4096-entry bound with overflow refusal. This matches document_lease.lua and atlas/modes/session_sync.md:170-172; the pinned correction is prose-only.

### Raised

- **BR-5** [Important] `window-option-ownership` (kind: defect) Buffer round trips restore another buffer's original window options
  lua/parley/document_band.lua:59 retires the previous buffer's record after the window already displays the next buffer; restore() therefore applies that previous record's baseline to the current buffer. A native headless A→B→A probe with distinct original options and identical rendered bands restored A to "original B" / "StatusLine:IncSearch", instead of "original A" / "StatusLine:Search". Preserve ownership and original values per window/buffer pair, or restore before leaving the owning buffer. Add round-trip coverage with distinct originals; the existing handoff test uses identical originals and misses this defect. ARCH-ORDER.

## Round 4 — 2026-10-15T22:18:14-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Native and public move preflight confirms OLD membership and rechecks busy state after yielding; admission and owned-move regressions pass.
- BR-2 — addressed — True unload retires the incarnation and lease; managed reads defer completions until reconciliation. All 10 buffer-lifetime regressions pass.
- BR-3 — addressed — The plan Core concepts table correctly classifies not_chat as INTEGRATION; init.lua retains the editor/filesystem-dependent wrapper.
- BR-4 — addressed — The plan explicitly states that lease files remain permanently allocated, automatic GC is absent, and allocation is capped at 4096 IDs per namespace; document_lease.lua implements that contract.
- BR-5 — addressed — document_band.lua preserves restoration proofs per window/buffer pair and checks buffer ownership before restoring. Both distinct-baseline round-trip tests pass at HEAD and fail when only the renderer is replaced with its pre-fix version, reproducing B's originals being restored into A.

## Open findings

(none — every finding has been disposed)
