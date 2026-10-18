---
gate: boundary-review
issue: 379
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 70f12047-441f-495f-b592-b4c283e9476d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000379"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/92f9b3e55b147601
            reviewed_head: 3f6ec81426a78f71a94b976be4632feb55899547
            slot: parley.nvim:4
            requested_at: "2026-10-18T04:18:53.78209Z"
          phase: finished
          pid: 53810
          started_at: "2026-10-18T04:18:53.877099Z"
          finished_at: "2026-10-18T04:22:04.964318Z"
          session_id: 24186cc3-723c-449f-ba65-b8079098cb38
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3f6ec81426a78f71a94b976be4632feb55899547
        tracker_head: f66fa7c08ffe3d5d37e03227037d4bcecad3c63f
        branch_point: 5cbad4b335ba1609bc5c481c99d4f6d36b076fbb
        since: "2026-10-17T17:27:55-07:00"
        until: "2026-10-17T18:03:39-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T17:27:55-07:00"
              end: "2026-10-17T18:03:39-07:00"
              began: "2026-10-17T17:27:55-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 54091665499ca91405fb98abd5962df3ac97da7fc691e222e7da7b3168724999
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 39876622
              windows:
                - start: "2026-10-17T17:27:55-07:00"
                  end: "2026-10-17T18:03:39-07:00"
      "n": 1
      timestamp: "2026-10-17T21:22:13-07:00"
      dispatched: "2026-10-17T21:18:53-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: scripts/test-nvim.sh --supported reports supported when its Lua check errors
          detail: nvim headless exits 0 after a -c Lua error (verified rc=0), so if require or vim.version() throws, the probe passes and the compat pass runs without the minimum-version message. Fix by wrapping the check in pcall and doing cquit 1 on any error, or by printing yes/no and grepping like has_mcode_fix. The --supported probe is the only instance in this window.
          family: probe-fail-open
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: help-parley does not list the new make test-compat target
          detail: Makefile.parley:7-26 lists every other test target; TOOLING.md documents test-compat but make help does not show it.
          family: help-listing-covers-targets
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: version_support_spec does not restore parley._setup_called after the setup refusal case
          detail: tests/unit/version_support_spec.lua:36 sets _setup_called to nil and never restores it. Harmless because each spec file runs in its own process.
          family: test-restores-global-state
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 3f6ec81426a78f71a94b976be4632feb55899547
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: cad3c3a9-d530-4e3c-98a3-3ec4d0ec64a3
            repository: github.com/xianxu/parley.nvim
            issue_id: "000379"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/da63bc43dbfdeccd
            reviewed_head: 9d14002faac5989a513086a70facc27869593ef5
            slot: parley.nvim:4
            requested_at: "2026-10-18T04:23:35.924597Z"
          phase: finished
          pid: 96448
          started_at: "2026-10-18T04:23:36.094026Z"
          finished_at: "2026-10-18T04:29:03.594372Z"
          session_id: 8270d301-2279-4a3b-9783-8e27da3644db
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9d14002faac5989a513086a70facc27869593ef5
        tracker_head: 0ad4d6b8ba6d2dd20e1283a3d6de39058f149031
        branch_point: 5cbad4b335ba1609bc5c481c99d4f6d36b076fbb
        since: "2026-10-17T17:27:55-07:00"
        until: "2026-10-17T21:23:00-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T17:27:55-07:00"
              end: "2026-10-17T21:23:00-07:00"
              began: "2026-10-17T17:27:55-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 858728db877ce8a0d9a73bd28149b3838fb31022f89caacedb1ecd9c588187ab
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 39999093
              windows:
                - start: "2026-10-17T17:27:55-07:00"
                  end: "2026-10-17T21:23:00-07:00"
        queue_waits:
            - attempt_id: 6aad4d7d49ca2e8e5111d3e5396998ea
              slot: parley.nvim:4
              record_digest: 1d8fbed4fafbf876412e2b4e26ff336607960c093641b635a26b5259c211a1b6
              start: "2026-10-18T01:19:54.83545Z"
              end: "2026-10-18T01:29:59.907983Z"
              queue_seconds: 605.072533
              raw_seconds: 605.072533
              exact: true
            - attempt_id: 0cb198c57867bcc74edce48490df5e36
              slot: parley.nvim:4
              record_digest: 3c990252597f78dc457b5b5bde0832c540c9eb6ae2ca7a769d480324d90e9e75
              start: "2026-10-18T01:32:03.881114Z"
              end: "2026-10-18T01:32:03.946321Z"
              queue_seconds: 0.065207
              raw_seconds: 0.065207
              exact: true
            - attempt_id: 79b669194101f25363e82e158f9fcaa2
              slot: parley.nvim:4
              record_digest: 6b183872e31198a9179a1f7ffea8a1aef8fa22fce8699bb99d600df653191460
              start: "2026-10-18T01:49:47.100078Z"
              end: "2026-10-18T02:00:37.518386Z"
              queue_seconds: 650.418308
              raw_seconds: 650.418308
              exact: true
            - attempt_id: 72129acae4bd7150417711f5816384ee
              slot: parley.nvim:4
              record_digest: 4bfeb7c3213238730a3445767419404abb36db10c60f4e87bb7d96743321d284
              start: "2026-10-18T02:09:31.666007Z"
              end: "2026-10-18T02:34:37.855292Z"
              queue_seconds: 1506.189285
              raw_seconds: 1506.189285
              exact: true
            - attempt_id: da08d57318cbdb23adf79c820442704e
              slot: parley.nvim:4
              record_digest: 3efcbc194d3237342ecffced04f564dc1e14b8f259221af03a9f400b307b8e48
              start: "2026-10-18T02:42:37.481398Z"
              end: "2026-10-18T03:01:02.235903Z"
              queue_seconds: 1104.754505
              raw_seconds: 1104.754505
              exact: true
            - attempt_id: 29a8d3bf622a9662d9b0da41eade5fe6
              slot: parley.nvim:4
              record_digest: 90928effd6839904153ae2406369579d89ab1b36a2fe784605b23e5f5f9114d9
              start: "2026-10-18T04:06:19.802303Z"
              end: "2026-10-18T04:13:12.284504Z"
              queue_seconds: 412.482201
              raw_seconds: 412.482201
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 83.57213333333333
        cuts:
            - dispatched: "2026-10-17T21:18:53-07:00"
              finalized: "2026-10-17T21:22:13-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-17T21:29:04-07:00"
      dispatched: "2026-10-17T21:23:35-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Probe accepts only an exact "yes". Verified: 0.11.7 rc=0; missing nvim, require throws, supported() throws, MINIMUM raised to 0.99 each rc=1 with a message.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: Makefile.parley:14 lists test-compat, and make help-parley shows it.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The spec saves and restores _setup_called alongside vim.version and vim.notify, then asserts on the captured value. The spec passes 5 of 5 under the harness.
          round: 2
      recipe: fix-review
      isolation: fenced
      reviewed: 9d14002faac5989a513086a70facc27869593ef5
      blocked: false
---

# Gate ledger — parley.nvim#379 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T21:22:13-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `probe-fail-open` (kind: defect) scripts/test-nvim.sh --supported reports supported when its Lua check errors
  nvim headless exits 0 after a -c Lua error (verified rc=0), so if require or vim.version() throws, the probe passes and the compat pass runs without the minimum-version message. Fix by wrapping the check in pcall and doing cquit 1 on any error, or by printing yes/no and grepping like has_mcode_fix. The --supported probe is the only instance in this window.
- **BR-2** [Minor] `help-listing-covers-targets` (kind: defect) help-parley does not list the new make test-compat target
  Makefile.parley:7-26 lists every other test target; TOOLING.md documents test-compat but make help does not show it.
- **BR-3** [Minor] `test-restores-global-state` (kind: defect) version_support_spec does not restore parley._setup_called after the setup refusal case
  tests/unit/version_support_spec.lua:36 sets _setup_called to nil and never restores it. Harmless because each spec file runs in its own process.

## Round 2 — 2026-10-17T21:29:04-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Probe accepts only an exact "yes". Verified: 0.11.7 rc=0; missing nvim, require throws, supported() throws, MINIMUM raised to 0.99 each rc=1 with a message.
- BR-2 — addressed — Makefile.parley:14 lists test-compat, and make help-parley shows it.
- BR-3 — addressed — The spec saves and restores _setup_called alongside vim.version and vim.notify, then asserts on the captured value. The spec passes 5 of 5 under the harness.

## Open findings

(none — every finding has been disposed)
