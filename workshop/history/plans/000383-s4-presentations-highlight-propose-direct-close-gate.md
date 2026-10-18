---
gate: boundary-review
issue: 383
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-18T05:49:46-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Tasks enumerate test cases in prose instead of one adversarial strategy line for presentation.decorations
          detail: |-
            Replace the case lists with: decorations over arbitrary rounds/lines, fuzzed with malformed or out-of-range spans, multibyte/CRLF text and empty or duplicate `new` text; the guard is that every output position lies within `lines` and nothing raises.
            (carried from plan-quality PQ-2, deferred to the boundary review)
          family: test-plan-enumeration
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 40fc91f3-228a-44ee-a9ae-838c5c382f85
            repository: github.com/xianxu/parley.nvim
            issue_id: "000383"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/fc79d6515db5a2ca
            reviewed_head: b11a4ac640ea1c93c0a673809812e271f3201923
            slot: parley.nvim:3
            requested_at: "2026-10-18T12:42:56.78332Z"
          phase: finished
          pid: 63682
          started_at: "2026-10-18T12:42:56.902592Z"
          finished_at: "2026-10-18T12:49:45.166201Z"
          session_id: 3fe98d6b-c55e-48a1-8f2e-c9b1c9a96a49
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: b11a4ac640ea1c93c0a673809812e271f3201923
        tracker_head: af4059645c0a2c9b05b6d62518af0df238c5b1ed
        branch_point: b6e19e2006181d074e036a1f989cb63bcd983b7a
        since: "2026-10-18T00:03:53-07:00"
        until: "2026-10-18T05:42:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T00:03:53-07:00"
              end: "2026-10-18T05:42:38-07:00"
              began: "2026-10-18T00:03:53-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 9700fb7b-67f3-4f36-922a-277d9ac1d46e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 5857320a0b5d69a958aeb9fc3643ca682c4f35fbfad7ba5371f5c11e7217c7b5
              started: "2026-10-18T11:51:54.902Z"
              spawned: false
              bytes: 373432
              windows:
                - start: "2026-10-18T11:51:54.902Z"
                  end: "2026-10-18T05:42:38-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ba44da9e11e5380d96c4d9238714ffef7a5ed7b82a724d038b6e051dd821f25a
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 33393024
              windows:
                - start: "2026-10-18T00:03:53-07:00"
                  end: "2026-10-18T05:42:38-07:00"
            - harness: claude
              id: e36c331e-3448-43b2-b2e9-2699764ffae8
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a6586597692c435c52e25402a3b9fa1a918ba34b793f9d0c97e165838bb6c5b6
              started: "2026-10-18T11:51:20.118Z"
              spawned: false
              bytes: 531466
              windows:
                - start: "2026-10-18T11:51:20.118Z"
                  end: "2026-10-18T05:42:38-07:00"
            - harness: claude
              id: ef12293d-4b6f-4c23-b8e1-ef727bd5d2a5
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: bfbdb8bfde90ea1be6ea60456b0d9fc7902662e06b3f8663ff5e43e5d3f99bd7
              started: "2026-10-18T11:49:05.093Z"
              spawned: false
              bytes: 562962
              windows:
                - start: "2026-10-18T11:49:05.093Z"
                  end: "2026-10-18T05:42:38-07:00"
        queue_waits:
            - attempt_id: f08b75714d7659d1dff169175d0cbb7c
              slot: parley.nvim:3
              record_digest: e66e1343bcdfb870fa5d33a9b4a547740e8f4702c8b428e190343e8e3d37ecce
              start: "2026-10-18T07:55:32.012565Z"
              end: "2026-10-18T08:24:39.728537Z"
              queue_seconds: 1747.715972
              raw_seconds: 1747.715972
              exact: true
            - attempt_id: 57025e6c6587590d130268762ab3d69f
              slot: parley.nvim:3
              record_digest: 2fc89ec1f237e2462fa10e44724233e944d9486c6c443fe709b837e2ffcf386e
              start: "2026-10-18T08:32:32.833227Z"
              end: "2026-10-18T08:56:19.779856Z"
              queue_seconds: 1426.946629
              raw_seconds: 1426.946629
              exact: true
            - attempt_id: 35b35e1c7025224d93be042835b2c3e4
              slot: parley.nvim:3
              record_digest: a266722d57e1ce98facdf3805cd1d2f63e3f49d74e203df88e46552e1fb01cf3
              start: "2026-10-18T09:04:52.742818Z"
              end: "2026-10-18T09:13:08.164612Z"
              queue_seconds: 495.421794
              raw_seconds: 495.421794
              exact: true
            - attempt_id: e31c018c7d832c42b3428375910f71dd
              slot: parley.nvim:3
              record_digest: 2f55a7691a79c9c09086ca2c4fd1b2e9a8f51916240bc19dcec1ccfd3eac671a
              start: "2026-10-18T12:20:08.151889Z"
              end: "2026-10-18T12:20:35.396906Z"
              queue_seconds: 27.245017
              raw_seconds: 27.245017
              exact: true
            - attempt_id: 412f5fbe915f3fadd9709f22e1c53150
              slot: parley.nvim:3
              record_digest: 535a525b3fe8cac2565176b8e20b286416c0ffe4731834c4158e3a38c30dda22
              start: "2026-10-18T12:24:29.455973Z"
              end: "2026-10-18T12:37:13.755485Z"
              queue_seconds: 764.299512
              raw_seconds: 764.299512
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 22.653233333333333
      "n": 2
      timestamp: "2026-10-18T05:49:46-07:00"
      dispatched: "2026-10-18T05:42:56-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-2
          severity: Important
          title: README update appears missing for the presentation frontmatter key and agent-round highlighting
          detail: The diff adds a user-typed frontmatter key presentation (direct, highlight or propose, default highlight), plus highlights with reasons that clear on a confirmed Alt+Return and the proposal side-doc link. atlas/modes/session_sync.md documents them; README.md (Couch pane paragraph near line 90) does not.
          family: readme-misses-user-surface
          round: 2
        - kind: defect
          id: BR-3
          severity: Minor
          title: Spec says DiffChange and clear_decorations; code uses DiffAdd and clear_round, with no plan Revisions entry
          detail: skill_render.lua:373 links ParleyAgentChange to DiffAdd. Clearing goes through edit_round.clear and clear_round to keep footnotes. Both deviate from the issue Spec text and should be recorded in the plan's Revisions, along with the dropped deletion re-anchor and the proposal-link spec's file.
          family: spec-plan-drift-unrecorded
          round: 2
        - kind: defect
          id: BR-4
          severity: Minor
          title: attach_diagnostics replaces the whole diagnostic namespace and drops round diagnostics until the next keystroke
          detail: skill_render.lua:238 (pre-existing) calls vim.diagnostic.set with only parley-skill entries. Round marks stay but their diagnostics vanish until on_lines triggers rederive_round.
          family: shared-namespace-wholesale-set
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: edit_round.clear resets attached but not pending, so a redraw can lose one re-derive batch
          detail: If a scheduled re-derive from the old token is pending when follow_edits re-attaches, the new on_lines sees pending set and skips, and the old callback returns on the token mismatch. A tagged per-buffer state would make this explicit.
          family: unwritten-flag-state-set
          round: 2
        - kind: defect
          id: BR-6
          severity: Minor
          title: Done-when live check on a real document is deferred to the operator's Couch restart
          detail: The hub approved it and the steps are in the issue Log. Offline conformance against the M1 binary stands in. Keep it tracked so the close does not imply it ran.
          family: deferred-done-when
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: fcd3daab-6610-4000-853d-de5164c98cf7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000383"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b7cd8e79013fbada
            reviewed_head: 7ec1433a42d89d2b35555b595cd837a018363e9a
            slot: parley.nvim:3
            requested_at: "2026-10-18T13:10:21.303694Z"
          phase: finished
          pid: 10027
          started_at: "2026-10-18T13:10:21.494735Z"
          finished_at: "2026-10-18T13:20:50.091601Z"
          session_id: b884b39a-1c2a-4fce-bc3f-850402b59a96
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 7ec1433a42d89d2b35555b595cd837a018363e9a
        tracker_head: af4059645c0a2c9b05b6d62518af0df238c5b1ed
        branch_point: b6e19e2006181d074e036a1f989cb63bcd983b7a
        since: "2026-10-18T00:03:53-07:00"
        until: "2026-10-18T05:50:32-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T00:03:53-07:00"
              end: "2026-10-18T05:50:32-07:00"
              began: "2026-10-18T00:03:53-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 9700fb7b-67f3-4f36-922a-277d9ac1d46e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 5857320a0b5d69a958aeb9fc3643ca682c4f35fbfad7ba5371f5c11e7217c7b5
              started: "2026-10-18T11:51:54.902Z"
              spawned: false
              bytes: 373432
              windows:
                - start: "2026-10-18T11:51:54.902Z"
                  end: "2026-10-18T05:50:32-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 36b5a56f98e3243aba414d28e281f4ed6c51b2337e1f124f6cac672631c91a12
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 33533296
              windows:
                - start: "2026-10-18T00:03:53-07:00"
                  end: "2026-10-18T05:50:32-07:00"
            - harness: claude
              id: e36c331e-3448-43b2-b2e9-2699764ffae8
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a6586597692c435c52e25402a3b9fa1a918ba34b793f9d0c97e165838bb6c5b6
              started: "2026-10-18T11:51:20.118Z"
              spawned: false
              bytes: 531466
              windows:
                - start: "2026-10-18T11:51:20.118Z"
                  end: "2026-10-18T05:50:32-07:00"
            - harness: claude
              id: ef12293d-4b6f-4c23-b8e1-ef727bd5d2a5
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: bfbdb8bfde90ea1be6ea60456b0d9fc7902662e06b3f8663ff5e43e5d3f99bd7
              started: "2026-10-18T11:49:05.093Z"
              spawned: false
              bytes: 562962
              windows:
                - start: "2026-10-18T11:49:05.093Z"
                  end: "2026-10-18T05:50:32-07:00"
        queue_waits:
            - attempt_id: f08b75714d7659d1dff169175d0cbb7c
              slot: parley.nvim:3
              record_digest: e66e1343bcdfb870fa5d33a9b4a547740e8f4702c8b428e190343e8e3d37ecce
              start: "2026-10-18T07:55:32.012565Z"
              end: "2026-10-18T08:24:39.728537Z"
              queue_seconds: 1747.715972
              raw_seconds: 1747.715972
              exact: true
            - attempt_id: 57025e6c6587590d130268762ab3d69f
              slot: parley.nvim:3
              record_digest: 2fc89ec1f237e2462fa10e44724233e944d9486c6c443fe709b837e2ffcf386e
              start: "2026-10-18T08:32:32.833227Z"
              end: "2026-10-18T08:56:19.779856Z"
              queue_seconds: 1426.946629
              raw_seconds: 1426.946629
              exact: true
            - attempt_id: 35b35e1c7025224d93be042835b2c3e4
              slot: parley.nvim:3
              record_digest: a266722d57e1ce98facdf3805cd1d2f63e3f49d74e203df88e46552e1fb01cf3
              start: "2026-10-18T09:04:52.742818Z"
              end: "2026-10-18T09:13:08.164612Z"
              queue_seconds: 495.421794
              raw_seconds: 495.421794
              exact: true
            - attempt_id: e31c018c7d832c42b3428375910f71dd
              slot: parley.nvim:3
              record_digest: 2f55a7691a79c9c09086ca2c4fd1b2e9a8f51916240bc19dcec1ccfd3eac671a
              start: "2026-10-18T12:20:08.151889Z"
              end: "2026-10-18T12:20:35.396906Z"
              queue_seconds: 27.245017
              raw_seconds: 27.245017
              exact: true
            - attempt_id: 412f5fbe915f3fadd9709f22e1c53150
              slot: parley.nvim:3
              record_digest: 535a525b3fe8cac2565176b8e20b286416c0ffe4731834c4158e3a38c30dda22
              start: "2026-10-18T12:24:29.455973Z"
              end: "2026-10-18T12:37:13.755485Z"
              queue_seconds: 764.299512
              raw_seconds: 764.299512
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 22.653233333333333
        cuts:
            - dispatched: "2026-10-18T05:42:56-07:00"
              finalized: "2026-10-18T05:49:46-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-18T06:20:50-07:00"
      dispatched: "2026-10-18T06:10:21-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Plan Task 2 carries the one-line adversarial strategy (plan:122) and presentation_spec.lua:70-109 implements it with a reach assertion; the leftover case list is harmless prose.
          round: 3
        - id: BR-2
          disposition: addressed
          note: 'README.md:102-110 now documents presentation: direct/highlight/propose, reasons, clearing on confirmed Alt+Return, the proposal link via Alt+o, the 200 cap, and the pair#661 requirement; it matches edit_round.lua and presentation.lua.'
          round: 3
        - id: BR-3
          disposition: addressed
          note: Plan Revisions (2026-10-18 close review) record DiffAdd vs DiffChange, clear_round vs clear_decorations, hash-only deletion placement, and the proposal-link spec file; matches skill_render.lua and edit_round.lua.
          round: 3
        - id: BR-4
          disposition: addressed
          note: skill_render.lua:239-240 restores the round kind; reverting it fails the new skill_render_round_spec case. Siblings of the class are raised as a new finding.
          round: 3
        - id: BR-5
          disposition: not-addressed
          note: edit_round.lua:120 now resets pending, but reverting it leaves edit_round_spec and edit_round_hooks_spec green; no regression test pins the lost-batch interleaving.
          round: 3
        - id: BR-6
          disposition: addressed
          note: Issue Task 6 states the live check is deferred to the operator's Couch restart, with steps in the Log; the close does not claim it ran.
          round: 3
      findings:
        - kind: defect
          id: BR-7
          severity: Minor
          title: apply_snapshot and clear_decorations still replace the shared namespace wholesale and wipe the agent round
          detail: '2nd finding in this family. The rule: every writer of the parley_skill diagnostic namespace replaces only the kind it owns, through one helper replace_kind(buf, is_kind, diagnostics). Prevalence, 6 writers in skill_render.lua. Three filter by kind (113, 132, 164). attach_diagnostics (238) is patched after the fact and still wipes footnote diagnostics, which is pre-existing. apply_snapshot (370, undo/redo via projection.lua:97) and clear_decorations (44, every skill round start at skill_invoke.lua:396) still clear everything. So the agent''s highlights vanish on a review-skill run or an undo/redo before the next confirmed submit, and the BR-4 restore rarely fires in production.'
          family: shared-namespace-wholesale-set
          round: 3
      recipe: milestone-review
      isolation: fenced
      reviewed: 7ec1433a42d89d2b35555b595cd837a018363e9a
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f846f7ad-d597-4a90-81d7-23f9eb9219bb
            repository: github.com/xianxu/parley.nvim
            issue_id: "000383"
            recipe: fix-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/11d8e13e5f0ce9a6
            reviewed_head: 845884bcc17313d4415e4935b8da9dc67bf786d9
            slot: parley.nvim:3
            requested_at: "2026-10-18T13:38:49.119147Z"
          phase: finished
          pid: 96509
          started_at: "2026-10-18T13:38:49.212511Z"
          finished_at: "2026-10-18T13:44:41.979253Z"
          session_id: 2918caaa-6710-4dca-b20e-8d22c05dd6b1
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 845884bcc17313d4415e4935b8da9dc67bf786d9
        tracker_head: af4059645c0a2c9b05b6d62518af0df238c5b1ed
        branch_point: b6e19e2006181d074e036a1f989cb63bcd983b7a
        since: "2026-10-18T00:03:53-07:00"
        until: "2026-10-18T06:22:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T00:03:53-07:00"
              end: "2026-10-18T06:22:48-07:00"
              began: "2026-10-18T00:03:53-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 9700fb7b-67f3-4f36-922a-277d9ac1d46e
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 5857320a0b5d69a958aeb9fc3643ca682c4f35fbfad7ba5371f5c11e7217c7b5
              started: "2026-10-18T11:51:54.902Z"
              spawned: false
              bytes: 373432
              windows:
                - start: "2026-10-18T11:51:54.902Z"
                  end: "2026-10-18T06:22:48-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 39b714a714823faf22f578725063bdb464820299a8adb1639ace2d0628dc95a5
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 33711721
              windows:
                - start: "2026-10-18T00:03:53-07:00"
                  end: "2026-10-18T06:22:48-07:00"
            - harness: claude
              id: e36c331e-3448-43b2-b2e9-2699764ffae8
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a6586597692c435c52e25402a3b9fa1a918ba34b793f9d0c97e165838bb6c5b6
              started: "2026-10-18T11:51:20.118Z"
              spawned: false
              bytes: 531466
              windows:
                - start: "2026-10-18T11:51:20.118Z"
                  end: "2026-10-18T06:22:48-07:00"
            - harness: claude
              id: ef12293d-4b6f-4c23-b8e1-ef727bd5d2a5
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: bfbdb8bfde90ea1be6ea60456b0d9fc7902662e06b3f8663ff5e43e5d3f99bd7
              started: "2026-10-18T11:49:05.093Z"
              spawned: false
              bytes: 562962
              windows:
                - start: "2026-10-18T11:49:05.093Z"
                  end: "2026-10-18T06:22:48-07:00"
        queue_waits:
            - attempt_id: f08b75714d7659d1dff169175d0cbb7c
              slot: parley.nvim:3
              record_digest: e66e1343bcdfb870fa5d33a9b4a547740e8f4702c8b428e190343e8e3d37ecce
              start: "2026-10-18T07:55:32.012565Z"
              end: "2026-10-18T08:24:39.728537Z"
              queue_seconds: 1747.715972
              raw_seconds: 1747.715972
              exact: true
            - attempt_id: 57025e6c6587590d130268762ab3d69f
              slot: parley.nvim:3
              record_digest: 2fc89ec1f237e2462fa10e44724233e944d9486c6c443fe709b837e2ffcf386e
              start: "2026-10-18T08:32:32.833227Z"
              end: "2026-10-18T08:56:19.779856Z"
              queue_seconds: 1426.946629
              raw_seconds: 1426.946629
              exact: true
            - attempt_id: 35b35e1c7025224d93be042835b2c3e4
              slot: parley.nvim:3
              record_digest: a266722d57e1ce98facdf3805cd1d2f63e3f49d74e203df88e46552e1fb01cf3
              start: "2026-10-18T09:04:52.742818Z"
              end: "2026-10-18T09:13:08.164612Z"
              queue_seconds: 495.421794
              raw_seconds: 495.421794
              exact: true
            - attempt_id: e31c018c7d832c42b3428375910f71dd
              slot: parley.nvim:3
              record_digest: 2f55a7691a79c9c09086ca2c4fd1b2e9a8f51916240bc19dcec1ccfd3eac671a
              start: "2026-10-18T12:20:08.151889Z"
              end: "2026-10-18T12:20:35.396906Z"
              queue_seconds: 27.245017
              raw_seconds: 27.245017
              exact: true
            - attempt_id: 412f5fbe915f3fadd9709f22e1c53150
              slot: parley.nvim:3
              record_digest: 535a525b3fe8cac2565176b8e20b286416c0ffe4731834c4158e3a38c30dda22
              start: "2026-10-18T12:24:29.455973Z"
              end: "2026-10-18T12:37:13.755485Z"
              queue_seconds: 764.299512
              raw_seconds: 764.299512
              exact: true
            - attempt_id: 217a57d72b3c640295913ce2f994dfed
              slot: parley.nvim:3
              record_digest: 7cf9d83b8abdafba14ab2b794226023752a03eaf1f3d07fc465f3e04201b3eff
              start: "2026-10-18T12:50:40.702865Z"
              end: "2026-10-18T13:02:58.730221Z"
              queue_seconds: 738.027356
              raw_seconds: 738.027356
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 22.653233333333333
        cuts:
            - dispatched: "2026-10-18T05:42:56-07:00"
              finalized: "2026-10-18T05:49:46-07:00"
              finalizing: false
            - dispatched: "2026-10-18T06:10:21-07:00"
              finalized: "2026-10-18T06:20:50-07:00"
              finalizing: true
      "n": 4
      timestamp: "2026-10-18T06:44:42-07:00"
      dispatched: "2026-10-18T06:38:49-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: not-addressed
          note: Fix is present (edit_round.lua:121 resets pending with attached) and is correct by inspection, but no spec fails without it; add a clear-then-redraw-then-keystroke rederive-count spec.
          round: 4
        - id: BR-7
          disposition: addressed
          note: All six writers go through replace_kind (skill_render.lua:59); snapshot filters the round out; skill_render_round_spec.lua:61-77 goes red at line 68 with skill_render.lua restored from 845884bc^ and green at head.
          round: 4
      findings:
        - kind: defect
          id: BR-8
          severity: Minor
          title: The dismiss binding no longer clears the agent's round, so the operator cannot hide the highlights on demand
          detail: skill_render.lua:85 aliases dismiss to clear_decorations, which now keeps the round. The plan Revisions entry says this is intended, but the doc comment still says it dismisses the live round decorations. Reword the comment, or add a separate round dismiss if hiding on demand is wanted.
          family: dismiss-scope-unstated
          round: 4
      recipe: fix-review
      isolation: fenced
      reviewed: 845884bcc17313d4415e4935b8da9dc67bf786d9
      blocked: false
---

# Gate ledger — parley.nvim#383 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T05:49:46-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `test-plan-enumeration` Tasks enumerate test cases in prose instead of one adversarial strategy line for presentation.decorations
  Replace the case lists with: decorations over arbitrary rounds/lines, fuzzed with malformed or out-of-range spans, multibyte/CRLF text and empty or duplicate `new` text; the guard is that every output position lies within `lines` and nothing raises.
  (carried from plan-quality PQ-2, deferred to the boundary review)

## Round 2 — 2026-10-18T05:49:46-07:00 (claude) — BLOCKED

### Raised

- **BR-2** [Important] `readme-misses-user-surface` (kind: defect) README update appears missing for the presentation frontmatter key and agent-round highlighting
  The diff adds a user-typed frontmatter key presentation (direct, highlight or propose, default highlight), plus highlights with reasons that clear on a confirmed Alt+Return and the proposal side-doc link. atlas/modes/session_sync.md documents them; README.md (Couch pane paragraph near line 90) does not.
- **BR-3** [Minor] `spec-plan-drift-unrecorded` (kind: defect) Spec says DiffChange and clear_decorations; code uses DiffAdd and clear_round, with no plan Revisions entry
  skill_render.lua:373 links ParleyAgentChange to DiffAdd. Clearing goes through edit_round.clear and clear_round to keep footnotes. Both deviate from the issue Spec text and should be recorded in the plan's Revisions, along with the dropped deletion re-anchor and the proposal-link spec's file.
- **BR-4** [Minor] `shared-namespace-wholesale-set` (kind: defect) attach_diagnostics replaces the whole diagnostic namespace and drops round diagnostics until the next keystroke
  skill_render.lua:238 (pre-existing) calls vim.diagnostic.set with only parley-skill entries. Round marks stay but their diagnostics vanish until on_lines triggers rederive_round.
- **BR-5** [Minor] `unwritten-flag-state-set` (kind: defect) edit_round.clear resets attached but not pending, so a redraw can lose one re-derive batch
  If a scheduled re-derive from the old token is pending when follow_edits re-attaches, the new on_lines sees pending set and skips, and the old callback returns on the token mismatch. A tagged per-buffer state would make this explicit.
- **BR-6** [Minor] `deferred-done-when` (kind: defect) Done-when live check on a real document is deferred to the operator's Couch restart
  The hub approved it and the steps are in the issue Log. Offline conformance against the M1 binary stands in. Keep it tracked so the close does not imply it ran.

## Round 3 — 2026-10-18T06:20:50-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Plan Task 2 carries the one-line adversarial strategy (plan:122) and presentation_spec.lua:70-109 implements it with a reach assertion; the leftover case list is harmless prose.
- BR-2 — addressed — README.md:102-110 now documents presentation: direct/highlight/propose, reasons, clearing on confirmed Alt+Return, the proposal link via Alt+o, the 200 cap, and the pair#661 requirement; it matches edit_round.lua and presentation.lua.
- BR-3 — addressed — Plan Revisions (2026-10-18 close review) record DiffAdd vs DiffChange, clear_round vs clear_decorations, hash-only deletion placement, and the proposal-link spec file; matches skill_render.lua and edit_round.lua.
- BR-4 — addressed — skill_render.lua:239-240 restores the round kind; reverting it fails the new skill_render_round_spec case. Siblings of the class are raised as a new finding.
- BR-5 — not-addressed — edit_round.lua:120 now resets pending, but reverting it leaves edit_round_spec and edit_round_hooks_spec green; no regression test pins the lost-batch interleaving.
- BR-6 — addressed — Issue Task 6 states the live check is deferred to the operator's Couch restart, with steps in the Log; the close does not claim it ran.

### Raised

- **BR-7** [Minor] `shared-namespace-wholesale-set` (kind: defect) apply_snapshot and clear_decorations still replace the shared namespace wholesale and wipe the agent round
  2nd finding in this family. The rule: every writer of the parley_skill diagnostic namespace replaces only the kind it owns, through one helper replace_kind(buf, is_kind, diagnostics). Prevalence, 6 writers in skill_render.lua. Three filter by kind (113, 132, 164). attach_diagnostics (238) is patched after the fact and still wipes footnote diagnostics, which is pre-existing. apply_snapshot (370, undo/redo via projection.lua:97) and clear_decorations (44, every skill round start at skill_invoke.lua:396) still clear everything. So the agent's highlights vanish on a review-skill run or an undo/redo before the next confirmed submit, and the BR-4 restore rarely fires in production.

## Round 4 — 2026-10-18T06:44:42-07:00 (claude) — passed

### Disposed

- BR-5 — not-addressed — Fix is present (edit_round.lua:121 resets pending with attached) and is correct by inspection, but no spec fails without it; add a clear-then-redraw-then-keystroke rederive-count spec.
- BR-7 — addressed — All six writers go through replace_kind (skill_render.lua:59); snapshot filters the round out; skill_render_round_spec.lua:61-77 goes red at line 68 with skill_render.lua restored from 845884bc^ and green at head.

### Raised

- **BR-8** [Minor] `dismiss-scope-unstated` (kind: defect) The dismiss binding no longer clears the agent's round, so the operator cannot hide the highlights on demand
  skill_render.lua:85 aliases dismiss to clear_decorations, which now keeps the round. The plan Revisions entry says this is intended, but the doc comment still says it dismisses the live round decorations. Reword the comment, or add a separate round dismiss if hiding on demand is wanted.

## Open findings

- **BR-5** [Minor] `unwritten-flag-state-set` (kind: defect) edit_round.clear resets attached but not pending, so a redraw can lose one re-derive batch
- **BR-8** [Minor] `dismiss-scope-unstated` (kind: defect) The dismiss binding no longer clears the agent's round, so the operator cannot hide the highlights on demand
