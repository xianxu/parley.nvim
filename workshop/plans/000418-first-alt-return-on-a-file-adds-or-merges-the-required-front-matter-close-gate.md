---
gate: boundary-review
issue: 418
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 1179896a-842c-47e1-89af-73910defb03a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/f59b742183b52f72
            reviewed_head: f2a99a337abe8510b23ee3763f1fa287bb4cc4ae
            slot: parley.nvim:3
            requested_at: "2026-10-23T16:28:53.69265Z"
          phase: finished
          pid: 97727
          started_at: "2026-10-23T16:28:53.8697Z"
          finished_at: "2026-10-23T16:36:45.263058Z"
          session_id: 01a16998-0a8c-7591-bcb8-272a68ce1f4d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f2a99a337abe8510b23ee3763f1fa287bb4cc4ae
        tracker_head: 5351b7c0a1041226b5da1c9e52d52c9b97218870
        branch_point: 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9
        since: "2026-10-23T00:21:40-07:00"
        until: "2026-10-23T09:28:20-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T00:21:40-07:00"
              end: "2026-10-23T09:28:20-07:00"
              began: "2026-10-23T00:21:40-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b84cd8e12364b78f0a74891c77442b16b398893e896c07001aa6530cbe7f35ba
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 21692894
              windows:
                - start: "2026-10-23T00:21:40-07:00"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a16843-aea0-7920-96a7-5d9a440c147c
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8f79c41cd5bb21ffaf35eee1b1e0133988a51ad6b991961f9ed0216b13c4d589
              started: "2026-10-23T10:17:09.366Z"
              spawned: false
              bytes: 646947
              windows:
                - start: "2026-10-23T10:17:09.366Z"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a16849-e2e5-78e3-b96e-38f5a790946e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ea5c452d1147954f1a55e0d3cbb571cb88f19aa8b31dcc090960ff3e59dade0b
              started: "2026-10-23T10:23:55.493Z"
              spawned: false
              bytes: 469439
              windows:
                - start: "2026-10-23T10:23:55.493Z"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a1684b-98a5-7ae1-8392-3526214286d4
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 1d936e6a2efbb27a483bbc55ce6d9a2c8df1283167abefb67f7310455ebd33f7
              started: "2026-10-23T10:25:47.68Z"
              spawned: false
              bytes: 438077
              windows:
                - start: "2026-10-23T10:25:47.68Z"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a1684c-19d5-7ea1-b48f-ce5bd7992a9a
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e55a55bf67be9c833ea10e4aaa06eef28c469ea88b42c3853329de37b8e1ce54
              started: "2026-10-23T10:26:20.787Z"
              spawned: false
              bytes: 445683
              windows:
                - start: "2026-10-23T10:26:20.787Z"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a1684d-cb40-7fc3-885d-86d14a401f1e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: cd27723ed96eccd2d8ba16564a8cb3a04b9a100d4cfb24b00442fa3e2902eb10
              started: "2026-10-23T10:28:11.397Z"
              spawned: true
              bytes: 2575090
              windows:
                - start: "2026-10-23T10:28:11.397Z"
                  end: "2026-10-23T09:28:20-07:00"
            - harness: codex
              id: 01a16859-5a99-75d2-b544-c30a65629d39
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: 882b04275187f4c2ec3dde4ae6a0608b4d025083709a1ab89f6db453c3ddff4b
              started: "2026-10-23T10:40:48.896Z"
              spawned: true
              bytes: 417223
              windows:
                - start: "2026-10-23T10:40:48.896Z"
                  end: "2026-10-23T09:28:20-07:00"
        queue_waits:
            - attempt_id: 781b67e502e28036977da46605addba4
              slot: parley.nvim:3
              record_digest: b6a93e7ac5a0b3e3cac87b6fff8f7355ae730d2c0faecec0202ba45427182473
              start: "2026-10-23T10:54:03.236141Z"
              end: "2026-10-23T11:34:53.777074Z"
              queue_seconds: 2450.540933
              raw_seconds: 2450.540933
              exact: true
            - attempt_id: 3bf568b5469d463898dc0993c1acdcb9
              slot: parley.nvim:3
              record_digest: 1ec2820680a4d19f80e2b897eba31787a9cff2439e1f65f4065bc1268f721a4c
              start: "2026-10-23T11:44:18.516335Z"
              end: "2026-10-23T12:26:26.799999Z"
              queue_seconds: 2528.283664
              raw_seconds: 2528.283664
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.1062
      "n": 1
      timestamp: "2026-10-23T09:36:47-07:00"
      dispatched: "2026-10-23T09:28:53-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Materialized instructions do not reliably round-trip as strings
          detail: 'lua/parley/editorial_frontmatter.lua:84-85 uses quoting rules that emit legacy instructions such as "true", "123", and "null" as unquoted canonical values. First fill succeeds, but filling its output fails with "processing-instruction: expected a scalar string"; this reproduces on Neovim 0.12.5 and 0.11.7. Escaped newlines also become literal newline characters inside an insertion entry. ARCH-EVOLVE / ARCH-SECURE: use a string serializer that preserves YAML types and escapes control characters, then add round-trip/idempotence and native insertion regressions covering these value classes.'
          family: persisted-scalar-roundtrip
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: Filling valid indented frontmatter refuses its own projected output
          detail: 'lua/parley/editorial_frontmatter.lua:96-114 always inserts root keys at column zero. For a header containing "  title: Example", resolve succeeds, but fill returns "frontmatter: inconsistent root mapping indentation"; the same failure reproduces with root indentation widths 1 through 4. ARCH-PURPOSE / ARCH-EVOLVE: preserve the existing root mapping indentation when inserting keys, and test successful fill, existing-byte preservation, and idempotence for indented headers.'
          family: preserve-root-mapping-layout
          round: 1
        - kind: defect
          id: BR-3
          severity: Critical
          title: Core-concepts tables classify an unchanged module as modified
          detail: 'workshop/plans/000418-first-submit-frontmatter-plan.md:53 and :72 list lua/parley/skills/review/instruction.lua as modified, but its pinned base-to-head diff is empty; the plan''s own :186 explicitly says its primitives remain unchanged. Under the required Core-concepts cross-check this contradiction is Critical. ARCH-PURPOSE: correct both table entries to describe reuse and add a Revisions entry aligning the inventory with the implemented ownership.'
          family: core-concept-inventory-accuracy
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: af8e98c2-6632-433d-98c6-0f6bcc1fa727
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/0849fc9bc9c49259
            reviewed_head: 46d9d0d195905092cf27f466d93ae1921b1bbbf7
            slot: parley.nvim:3
            requested_at: "2026-10-23T16:45:29.720946Z"
          phase: finished
          pid: 56622
          started_at: "2026-10-23T16:45:29.934339Z"
          finished_at: "2026-10-23T16:49:09.222372Z"
          session_id: 01a169a7-3d63-76b3-a9a5-18570676b62b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 46d9d0d195905092cf27f466d93ae1921b1bbbf7
        tracker_head: 5eae4e0a2462f211e15ed57c7e9d10a33d686e35
        branch_point: 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9
        since: "2026-10-23T00:21:40-07:00"
        until: "2026-10-23T09:44:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T00:21:40-07:00"
              end: "2026-10-23T09:44:18-07:00"
              began: "2026-10-23T00:21:40-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ea1168614fd66aa40f053e6d78bd36bb0f1a20344a2e79bf59ea6caf7f990885
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 22381487
              windows:
                - start: "2026-10-23T00:21:40-07:00"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a16843-aea0-7920-96a7-5d9a440c147c
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8f79c41cd5bb21ffaf35eee1b1e0133988a51ad6b991961f9ed0216b13c4d589
              started: "2026-10-23T10:17:09.366Z"
              spawned: false
              bytes: 646947
              windows:
                - start: "2026-10-23T10:17:09.366Z"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a16849-e2e5-78e3-b96e-38f5a790946e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ea5c452d1147954f1a55e0d3cbb571cb88f19aa8b31dcc090960ff3e59dade0b
              started: "2026-10-23T10:23:55.493Z"
              spawned: false
              bytes: 469439
              windows:
                - start: "2026-10-23T10:23:55.493Z"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a1684b-98a5-7ae1-8392-3526214286d4
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 1d936e6a2efbb27a483bbc55ce6d9a2c8df1283167abefb67f7310455ebd33f7
              started: "2026-10-23T10:25:47.68Z"
              spawned: false
              bytes: 438077
              windows:
                - start: "2026-10-23T10:25:47.68Z"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a1684c-19d5-7ea1-b48f-ce5bd7992a9a
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e55a55bf67be9c833ea10e4aaa06eef28c469ea88b42c3853329de37b8e1ce54
              started: "2026-10-23T10:26:20.787Z"
              spawned: false
              bytes: 445683
              windows:
                - start: "2026-10-23T10:26:20.787Z"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a1684d-cb40-7fc3-885d-86d14a401f1e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: fa3f0deb6c136b52e9c2aade8243d99e6dbc0544497db3ccb62d40db80f96ef9
              started: "2026-10-23T10:28:11.397Z"
              spawned: true
              bytes: 2975283
              windows:
                - start: "2026-10-23T10:28:11.397Z"
                  end: "2026-10-23T09:44:18-07:00"
            - harness: codex
              id: 01a16859-5a99-75d2-b544-c30a65629d39
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: 92a74897a4e8a3dc16e224c1c1bc8f4dd7cece5e48574cdf60afe8586354b735
              started: "2026-10-23T10:40:48.896Z"
              spawned: true
              bytes: 530792
              windows:
                - start: "2026-10-23T10:40:48.896Z"
                  end: "2026-10-23T09:44:18-07:00"
        queue_waits:
            - attempt_id: 781b67e502e28036977da46605addba4
              slot: parley.nvim:3
              record_digest: b6a93e7ac5a0b3e3cac87b6fff8f7355ae730d2c0faecec0202ba45427182473
              start: "2026-10-23T10:54:03.236141Z"
              end: "2026-10-23T11:34:53.777074Z"
              queue_seconds: 2450.540933
              raw_seconds: 2450.540933
              exact: true
            - attempt_id: 3bf568b5469d463898dc0993c1acdcb9
              slot: parley.nvim:3
              record_digest: 1ec2820680a4d19f80e2b897eba31787a9cff2439e1f65f4065bc1268f721a4c
              start: "2026-10-23T11:44:18.516335Z"
              end: "2026-10-23T12:26:26.799999Z"
              queue_seconds: 2528.283664
              raw_seconds: 2528.283664
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.1062
        cuts:
            - dispatched: "2026-10-23T09:28:53-07:00"
              finalized: "2026-10-23T09:36:47-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-23T09:49:13-07:00"
      dispatched: "2026-10-23T09:45:29-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Generated implicit-type/control-character round-trip tests and native insertion tests pass. Removing the serializer fix in a disposable pinned-head copy causes two existing regression tests to fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Widths 1–4 preserve existing bytes and produce idempotent output; native indented submission passes. Removing indentation preservation causes the existing generated regression to fail.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Plan lines 53 and 73 now identify instruction.lua as unchanged reuse; line 72 lists the actual modified consumers. The pinned instruction.lua diff is empty, and the Revisions entry explains the corrected ownership.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Critical
          title: Valid plain instruction strings are rejected using flow-collection parsing rules
          detail: 'lua/parley/skills/review/collaboration_value.lua:257 calls decode(text) without block-scalar context. Consequently processing-instruction: Keep voice, fix typos fails with "expected a scalar string"; interior brackets and closing braces fail too. Reproduced on Neovim 0.12.5 and 0.11.7, including complete headers requiring no insertion. This blocks both submission routes for valid existing settings (ARCH-PURPOSE / ARCH-EVOLVE). This is the 2nd finding in family persisted-scalar-roundtrip: fix the rule across scalar reading and writing, rather than special-casing punctuation. Enumerate plain and quoted canonical/legacy instructions containing flow punctuation, verify effective-value preservation and idempotence, and add native submission coverage. Decode root scalar values in block context while retaining rejection of actual collections and invalid known-field types.'
          family: persisted-scalar-roundtrip
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: bdad0e79-c0a4-467b-a731-5c5706528596
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/563af1230bae8ddb
            reviewed_head: 2617a3b471acf68263b917b341d32d34c7963d69
            slot: parley.nvim:3
            requested_at: "2026-10-23T17:00:56.913048Z"
          phase: finished
          pid: 17336
          started_at: "2026-10-23T17:00:57.080144Z"
          finished_at: "2026-10-23T17:05:02.362414Z"
          session_id: 01a169b5-62fa-70c0-a68a-1264cc5af9cc
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2617a3b471acf68263b917b341d32d34c7963d69
        tracker_head: 68cc25edcb334bde91dd40403b76b9e972a65183
        branch_point: 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9
        since: "2026-10-23T00:21:40-07:00"
        until: "2026-10-23T10:00:07-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T00:21:40-07:00"
              end: "2026-10-23T10:00:07-07:00"
              began: "2026-10-23T00:21:40-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 843dac9808933d7cca52f23b771596b4b838be970fd20aceb28ca670830be34a
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 23797986
              windows:
                - start: "2026-10-23T00:21:40-07:00"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a16843-aea0-7920-96a7-5d9a440c147c
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8f79c41cd5bb21ffaf35eee1b1e0133988a51ad6b991961f9ed0216b13c4d589
              started: "2026-10-23T10:17:09.366Z"
              spawned: false
              bytes: 646947
              windows:
                - start: "2026-10-23T10:17:09.366Z"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a16849-e2e5-78e3-b96e-38f5a790946e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ea5c452d1147954f1a55e0d3cbb571cb88f19aa8b31dcc090960ff3e59dade0b
              started: "2026-10-23T10:23:55.493Z"
              spawned: false
              bytes: 469439
              windows:
                - start: "2026-10-23T10:23:55.493Z"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a1684b-98a5-7ae1-8392-3526214286d4
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 1d936e6a2efbb27a483bbc55ce6d9a2c8df1283167abefb67f7310455ebd33f7
              started: "2026-10-23T10:25:47.68Z"
              spawned: false
              bytes: 438077
              windows:
                - start: "2026-10-23T10:25:47.68Z"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a1684c-19d5-7ea1-b48f-ce5bd7992a9a
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e55a55bf67be9c833ea10e4aaa06eef28c469ea88b42c3853329de37b8e1ce54
              started: "2026-10-23T10:26:20.787Z"
              spawned: false
              bytes: 445683
              windows:
                - start: "2026-10-23T10:26:20.787Z"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a1684d-cb40-7fc3-885d-86d14a401f1e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: 06dd75bfcadf0cd6f38b8db0ac20e927f2d1092cc531775940045630b8684288
              started: "2026-10-23T10:28:11.397Z"
              spawned: true
              bytes: 3097958
              windows:
                - start: "2026-10-23T10:28:11.397Z"
                  end: "2026-10-23T10:00:07-07:00"
            - harness: codex
              id: 01a16859-5a99-75d2-b544-c30a65629d39
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: 17cb20a3f413c84f0719c4abb01dfaa0d6941d6eea8e0dad626e7938fe7d1dc5
              started: "2026-10-23T10:40:48.896Z"
              spawned: true
              bytes: 659848
              windows:
                - start: "2026-10-23T10:40:48.896Z"
                  end: "2026-10-23T10:00:07-07:00"
        queue_waits:
            - attempt_id: 781b67e502e28036977da46605addba4
              slot: parley.nvim:3
              record_digest: b6a93e7ac5a0b3e3cac87b6fff8f7355ae730d2c0faecec0202ba45427182473
              start: "2026-10-23T10:54:03.236141Z"
              end: "2026-10-23T11:34:53.777074Z"
              queue_seconds: 2450.540933
              raw_seconds: 2450.540933
              exact: true
            - attempt_id: 3bf568b5469d463898dc0993c1acdcb9
              slot: parley.nvim:3
              record_digest: 1ec2820680a4d19f80e2b897eba31787a9cff2439e1f65f4065bc1268f721a4c
              start: "2026-10-23T11:44:18.516335Z"
              end: "2026-10-23T12:26:26.799999Z"
              queue_seconds: 2528.283664
              raw_seconds: 2528.283664
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.241266666666666
        cuts:
            - dispatched: "2026-10-23T09:28:53-07:00"
              finalized: "2026-10-23T09:36:47-07:00"
              finalizing: false
            - dispatched: "2026-10-23T09:45:29-07:00"
              finalized: "2026-10-23T09:49:13-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-23T10:05:03-07:00"
      dispatched: "2026-10-23T10:00:56-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: editorial_frontmatter.lua:84–97 preserves materialized string types and escapes controls. Regression tests pass; removing JSON encoding in memory produces four failing cases.
          round: 3
        - id: BR-2
          disposition: addressed
          note: editorial_frontmatter.lua:118–120 preserves root indentation. Pure width-1–4 and native submission cases pass; removing indentation in memory makes the regression fail.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Both plan inventory rows now classify instruction.lua as unchanged, reused (lines 53 and 73), supported by its empty pinned-range diff and the explanation at line 203.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: 'Critical; family persisted-scalar-roundtrip; ARCH-PURPOSE / ARCH-EVOLVE. collaboration_value.lua:18–20 still recognizes a quote following punctuation as a quoted-value opener inside a root plain scalar. Valid processing-instruction: Keep commas, "please therefore fails with frontmatter: unclosed quoted value, including a complete header needing no insertion. The same occurs for Keep ["asides] intact and Keep -"voice intact: all 12 canonical/legacy × partial/complete combinations were rejected on Neovim 0.11.7, with representative failures also reproduced on 0.12.5. Ruby YAML accepts these strings. An in-memory extension of the existing native complete-header regression fails at editorial_submit_spec.lua:147 with no submission. Correct lexical context throughout header scanning, comment handling and scalar decoding; enumerate embedded quotes after punctuation across plain/quoted canonical/legacy values and partial/complete headers. Retain actual collection/type rejection and original-byte preservation.'
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#418 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T09:36:47-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `persisted-scalar-roundtrip` (kind: defect) Materialized instructions do not reliably round-trip as strings
  lua/parley/editorial_frontmatter.lua:84-85 uses quoting rules that emit legacy instructions such as "true", "123", and "null" as unquoted canonical values. First fill succeeds, but filling its output fails with "processing-instruction: expected a scalar string"; this reproduces on Neovim 0.12.5 and 0.11.7. Escaped newlines also become literal newline characters inside an insertion entry. ARCH-EVOLVE / ARCH-SECURE: use a string serializer that preserves YAML types and escapes control characters, then add round-trip/idempotence and native insertion regressions covering these value classes.
- **BR-2** [Critical] `preserve-root-mapping-layout` (kind: defect) Filling valid indented frontmatter refuses its own projected output
  lua/parley/editorial_frontmatter.lua:96-114 always inserts root keys at column zero. For a header containing "  title: Example", resolve succeeds, but fill returns "frontmatter: inconsistent root mapping indentation"; the same failure reproduces with root indentation widths 1 through 4. ARCH-PURPOSE / ARCH-EVOLVE: preserve the existing root mapping indentation when inserting keys, and test successful fill, existing-byte preservation, and idempotence for indented headers.
- **BR-3** [Critical] `core-concept-inventory-accuracy` (kind: defect) Core-concepts tables classify an unchanged module as modified
  workshop/plans/000418-first-submit-frontmatter-plan.md:53 and :72 list lua/parley/skills/review/instruction.lua as modified, but its pinned base-to-head diff is empty; the plan's own :186 explicitly says its primitives remain unchanged. Under the required Core-concepts cross-check this contradiction is Critical. ARCH-PURPOSE: correct both table entries to describe reuse and add a Revisions entry aligning the inventory with the implemented ownership.

## Round 2 — 2026-10-23T09:49:13-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Generated implicit-type/control-character round-trip tests and native insertion tests pass. Removing the serializer fix in a disposable pinned-head copy causes two existing regression tests to fail.
- BR-2 — addressed — Widths 1–4 preserve existing bytes and produce idempotent output; native indented submission passes. Removing indentation preservation causes the existing generated regression to fail.
- BR-3 — addressed — Plan lines 53 and 73 now identify instruction.lua as unchanged reuse; line 72 lists the actual modified consumers. The pinned instruction.lua diff is empty, and the Revisions entry explains the corrected ownership.

### Raised

- **BR-4** [Critical] `persisted-scalar-roundtrip` (kind: defect) Valid plain instruction strings are rejected using flow-collection parsing rules
  lua/parley/skills/review/collaboration_value.lua:257 calls decode(text) without block-scalar context. Consequently processing-instruction: Keep voice, fix typos fails with "expected a scalar string"; interior brackets and closing braces fail too. Reproduced on Neovim 0.12.5 and 0.11.7, including complete headers requiring no insertion. This blocks both submission routes for valid existing settings (ARCH-PURPOSE / ARCH-EVOLVE). This is the 2nd finding in family persisted-scalar-roundtrip: fix the rule across scalar reading and writing, rather than special-casing punctuation. Enumerate plain and quoted canonical/legacy instructions containing flow punctuation, verify effective-value preservation and idempotence, and add native submission coverage. Decode root scalar values in block context while retaining rejection of actual collections and invalid known-field types.

## Round 3 — 2026-10-23T10:05:03-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — editorial_frontmatter.lua:84–97 preserves materialized string types and escapes controls. Regression tests pass; removing JSON encoding in memory produces four failing cases.
- BR-2 — addressed — editorial_frontmatter.lua:118–120 preserves root indentation. Pure width-1–4 and native submission cases pass; removing indentation in memory makes the regression fail.
- BR-3 — addressed — Both plan inventory rows now classify instruction.lua as unchanged, reused (lines 53 and 73), supported by its empty pinned-range diff and the explanation at line 203.
- BR-4 — not-addressed — Critical; family persisted-scalar-roundtrip; ARCH-PURPOSE / ARCH-EVOLVE. collaboration_value.lua:18–20 still recognizes a quote following punctuation as a quoted-value opener inside a root plain scalar. Valid processing-instruction: Keep commas, "please therefore fails with frontmatter: unclosed quoted value, including a complete header needing no insertion. The same occurs for Keep ["asides] intact and Keep -"voice intact: all 12 canonical/legacy × partial/complete combinations were rejected on Neovim 0.11.7, with representative failures also reproduced on 0.12.5. Ruby YAML accepts these strings. An in-memory extension of the existing native complete-header regression fails at editorial_submit_spec.lua:147 with no submission. Correct lexical context throughout header scanning, comment handling and scalar decoding; enumerate embedded quotes after punctuation across plain/quoted canonical/legacy values and partial/complete headers. Retain actual collection/type rejection and original-byte preservation.

## Open findings

- **BR-4** [Critical] `persisted-scalar-roundtrip` (kind: defect) Valid plain instruction strings are rejected using flow-collection parsing rules
