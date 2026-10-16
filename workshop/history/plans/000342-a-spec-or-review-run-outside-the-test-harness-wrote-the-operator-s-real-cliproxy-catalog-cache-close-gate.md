---
gate: boundary-review
issue: 342
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 25bc033e-e7a4-4ffb-b37b-41c680091573
            repository: github.com/xianxu/parley.nvim
            issue_id: "000342"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/c750dab8ab35d7bb
            reviewed_head: 8089b376b0b3ab06e3a566a96673079411191d44
            slot: parley.nvim:3
            requested_at: "2026-10-16T04:04:41.906788Z"
          phase: finished
          pid: 84955
          started_at: "2026-10-16T04:04:42.518822Z"
          finished_at: "2026-10-16T04:06:03.527915Z"
          session_id: a2147ce9-5198-40a7-bc1d-2bf2c21b358f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8089b376b0b3ab06e3a566a96673079411191d44
        tracker_head: b63bdc2885ff9d24fb52a633c0cc0d3cce978ee9
        branch_point: 3d0c2369d1e25b61819b3554cdf1fd7950e7823f
        since: "2026-10-15T20:29:30-07:00"
        until: "2026-10-15T21:03:46-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T20:29:30-07:00"
              end: "2026-10-15T21:03:46-07:00"
              began: "2026-10-15T20:29:30-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 3de3c7a092989b53b550e6d456dc0af4e0963228bd14bb64e3d36132cf8c86f5
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 5687574
              windows:
                - start: "2026-10-15T20:29:30-07:00"
                  end: "2026-10-15T21:03:46-07:00"
      "n": 1
      timestamp: "2026-10-15T21:06:04-07:00"
      dispatched: "2026-10-15T21:04:41-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: TEST_ENV does not pin XDG_CONFIG_HOME, but check() refuses an outside value, so make test fails for operators who export it
          detail: 'Makefile.parley:54 sets HOME and the DATA, STATE and CACHE XDG roots only; test_isolation.lua:41-46 rejects a set XDG_CONFIG_HOME outside PARLEY_TEST_ENV_ROOT. An exported XDG_CONFIG_HOME is inherited into every harness nvim, and minimal_init then cquits on every spec with a "run through make" hint. Fix: add XDG_CONFIG_HOME="$(TEST_XDG)/config" to TEST_ENV (or unset it), plus a regression test. XDG_CONFIG_HOME is the only member of this family.'
          family: harness-env-pins-every-checked-root
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Documented direct nvim -u tests/minimal_init.vim runs left in record_fixtures.lua and perf_chat_finder.lua; the guard now refuses both
          detail: 'refresh_goldens.lua was moved to make goldens, but scripts/record_fixtures.lua:10-13 still documents an "or directly" run. tests/perf_chat_finder.lua:4 documents a direct -l run and has no make target, so the benchmark has no working entry point. Sweep the family: point record_fixtures at make fixtures only, and give perf_chat_finder a make target under TEST_ENV or a harness-wrapped usage line.'
          family: direct-run-entry-points-swept
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Spec bullet 3 (close-review instructions say to use make test-spec) deferred to ariadne without a tracked follow-up
          detail: The Log says the dispatcher is out of reach here. Record a follow-up issue reference so the deferral is tracked.
          family: spec-clause-deferred-untracked
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: minimal_init isolation heredoc does not stop the run if require of parley.test_isolation errors
          detail: A Lua error in an init heredoc is reported and startup continues, so the guard is skipped. Wrap the check in pcall and cquit when it fails.
          family: guard-fails-closed
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4e7f66b2-bb41-44c0-a896-b70f2646446a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000342"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/2fe17c524fe833bc
            reviewed_head: d4677890cc2ba8539394c6d4f9c97ded4d3176f3
            slot: parley.nvim:3
            requested_at: "2026-10-16T04:24:21.228857Z"
          phase: finished
          pid: 66902
          started_at: "2026-10-16T04:24:21.325645Z"
          finished_at: "2026-10-16T04:26:25.733014Z"
          session_id: f1f531f0-3fa2-4975-98b0-b752cf805f31
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d4677890cc2ba8539394c6d4f9c97ded4d3176f3
        tracker_head: b0f131dfc17bc41c87e07e8b59cdc2a0251ef39b
        branch_point: 3d0c2369d1e25b61819b3554cdf1fd7950e7823f
        since: "2026-10-15T20:29:30-07:00"
        until: "2026-10-15T21:24:04-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T20:29:30-07:00"
              end: "2026-10-15T21:24:04-07:00"
              began: "2026-10-15T20:29:30-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 889d1776c7c2fd011ee844bd8afcd8f365f7453f0a9b0ff4b64e19288278059a
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 5880340
              windows:
                - start: "2026-10-15T20:29:30-07:00"
                  end: "2026-10-15T21:24:04-07:00"
        cuts:
            - dispatched: "2026-10-15T21:04:41-07:00"
              finalized: "2026-10-15T21:06:04-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T21:26:26-07:00"
      dispatched: "2026-10-15T21:24:21-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Makefile.parley:54 TEST_ENV pins XDG_CONFIG_HOME, PREP_TEST_ENV creates it; test_isolation.ROOTS is the single list and tests/unit/test_isolation_spec.lua:47-60 asserts TEST_ENV assigns every entry (passes 9/0 here).
          round: 2
        - id: BR-2
          disposition: addressed
          note: record_fixtures.lua and perf_chat_finder.lua point at make fixtures and the new make perf-finder (Makefile.parley:233-239, under TEST_ENV); tree grep finds no remaining live direct-run instructions outside archival workshop/continuation notes.
          round: 2
        - id: BR-3
          disposition: withdrawn
          note: Log records a TL decision with rationale - the init guard enforces the make route with an actionable message, stronger than an instruction; the deferral is a recorded decision, not untracked.
          round: 2
        - id: BR-4
          disposition: addressed
          note: minimal_init.vim:16-17 wraps the require+check in pcall and converts failure into a refusal; integration case "fails closed when the isolation check itself cannot load" exercises it (4/0 here).
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: help-parley omits the new make goldens and make perf-finder targets
          detail: Makefile.parley:5-21 help text lists test, perf, fixtures etc. but not the two targets this window adds (the only two new targets); TOOLING.md:8 names them, make help does not.
          family: make-help-lists-every-target
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: d4677890cc2ba8539394c6d4f9c97ded4d3176f3
      blocked: false
---

# Gate ledger — parley.nvim#342 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T21:06:04-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `harness-env-pins-every-checked-root` (kind: defect) TEST_ENV does not pin XDG_CONFIG_HOME, but check() refuses an outside value, so make test fails for operators who export it
  Makefile.parley:54 sets HOME and the DATA, STATE and CACHE XDG roots only; test_isolation.lua:41-46 rejects a set XDG_CONFIG_HOME outside PARLEY_TEST_ENV_ROOT. An exported XDG_CONFIG_HOME is inherited into every harness nvim, and minimal_init then cquits on every spec with a "run through make" hint. Fix: add XDG_CONFIG_HOME="$(TEST_XDG)/config" to TEST_ENV (or unset it), plus a regression test. XDG_CONFIG_HOME is the only member of this family.
- **BR-2** [Important] `direct-run-entry-points-swept` (kind: defect) Documented direct nvim -u tests/minimal_init.vim runs left in record_fixtures.lua and perf_chat_finder.lua; the guard now refuses both
  refresh_goldens.lua was moved to make goldens, but scripts/record_fixtures.lua:10-13 still documents an "or directly" run. tests/perf_chat_finder.lua:4 documents a direct -l run and has no make target, so the benchmark has no working entry point. Sweep the family: point record_fixtures at make fixtures only, and give perf_chat_finder a make target under TEST_ENV or a harness-wrapped usage line.
- **BR-3** [Minor] `spec-clause-deferred-untracked` (kind: defect) Spec bullet 3 (close-review instructions say to use make test-spec) deferred to ariadne without a tracked follow-up
  The Log says the dispatcher is out of reach here. Record a follow-up issue reference so the deferral is tracked.
- **BR-4** [Minor] `guard-fails-closed` (kind: defect) minimal_init isolation heredoc does not stop the run if require of parley.test_isolation errors
  A Lua error in an init heredoc is reported and startup continues, so the guard is skipped. Wrap the check in pcall and cquit when it fails.

## Round 2 — 2026-10-15T21:26:26-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Makefile.parley:54 TEST_ENV pins XDG_CONFIG_HOME, PREP_TEST_ENV creates it; test_isolation.ROOTS is the single list and tests/unit/test_isolation_spec.lua:47-60 asserts TEST_ENV assigns every entry (passes 9/0 here).
- BR-2 — addressed — record_fixtures.lua and perf_chat_finder.lua point at make fixtures and the new make perf-finder (Makefile.parley:233-239, under TEST_ENV); tree grep finds no remaining live direct-run instructions outside archival workshop/continuation notes.
- BR-3 — withdrawn — Log records a TL decision with rationale - the init guard enforces the make route with an actionable message, stronger than an instruction; the deferral is a recorded decision, not untracked.
- BR-4 — addressed — minimal_init.vim:16-17 wraps the require+check in pcall and converts failure into a refusal; integration case "fails closed when the isolation check itself cannot load" exercises it (4/0 here).

### Raised

- **BR-5** [Minor] `make-help-lists-every-target` (kind: defect) help-parley omits the new make goldens and make perf-finder targets
  Makefile.parley:5-21 help text lists test, perf, fixtures etc. but not the two targets this window adds (the only two new targets); TOOLING.md:8 names them, make help does not.

## Open findings

- **BR-5** [Minor] `make-help-lists-every-target` (kind: defect) help-parley omits the new make goldens and make perf-finder targets
