---
gate: boundary-review
issue: 366
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8aba6309-5b3e-46cf-9d0c-59e2c916be5d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000366"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1cedac7218701796
            reviewed_head: e6b4a8de051080a9f129ad213dab016e38ac8e6a
            slot: parley.nvim:3
            requested_at: "2026-10-17T08:47:34.897775Z"
          phase: finished
          pid: 57554
          started_at: "2026-10-17T08:47:35.004486Z"
          finished_at: "2026-10-17T08:48:50.69771Z"
          session_id: 656ce6f3-6948-4c08-8390-b107bfc71edc
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: e6b4a8de051080a9f129ad213dab016e38ac8e6a
        tracker_head: 2a68bc9d84182e2903c0e70267cc14907915a1fe
        branch_point: 4db64fd9862fe0b2deaf6240852c6fe0afb64da0
        since: "2026-10-16T23:59:12-07:00"
        until: "2026-10-17T01:46:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T23:59:12-07:00"
              end: "2026-10-17T01:46:59-07:00"
              began: "2026-10-16T23:59:12-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 0591efa83f56f93bea0e5e52c9715b851d4c0c1cfcc3a20dcd324ada19737b93
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 22158946
              windows:
                - start: "2026-10-16T23:59:12-07:00"
                  end: "2026-10-17T01:46:59-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 48.8981
      "n": 1
      timestamp: "2026-10-17T01:48:51-07:00"
      dispatched: "2026-10-17T01:47:34-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: atlas says pending shows the first stderr line; the code falls back to stdout, then "no output"
          detail: atlas/infra/test_harness.md:101-102 vs tests/unit/couch_spec.lua:56. This is the only instance in the window. Reword to "the first line of its stderr (else stdout)".
          family: doc-claim-drifts-from-code
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: No static check pins PARLEY_LIVE_COUCH_DATA_HOME in the check-couch-actors-live recipe
          detail: 'If Makefile.parley:332 drops PARLEY_LIVE_COUCH_DATA_HOME, or couch_spec.lua:52 stops reading it, the live case quietly goes back to pending, which is the failure #366 fixed. tests/unit/test_isolation_spec.lua already reads Makefile text, so a one-line assertion there would cover it.'
          family: live-wiring-unpinned
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: e6b4a8de051080a9f129ad213dab016e38ac8e6a
      blocked: false
---

# Gate ledger — parley.nvim#366 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T01:48:51-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-drifts-from-code` (kind: defect) atlas says pending shows the first stderr line; the code falls back to stdout, then "no output"
  atlas/infra/test_harness.md:101-102 vs tests/unit/couch_spec.lua:56. This is the only instance in the window. Reword to "the first line of its stderr (else stdout)".
- **BR-2** [Minor] `live-wiring-unpinned` (kind: defect) No static check pins PARLEY_LIVE_COUCH_DATA_HOME in the check-couch-actors-live recipe
  If Makefile.parley:332 drops PARLEY_LIVE_COUCH_DATA_HOME, or couch_spec.lua:52 stops reading it, the live case quietly goes back to pending, which is the failure #366 fixed. tests/unit/test_isolation_spec.lua already reads Makefile text, so a one-line assertion there would cover it.

## Open findings

- **BR-1** [Minor] `doc-claim-drifts-from-code` (kind: defect) atlas says pending shows the first stderr line; the code falls back to stdout, then "no output"
- **BR-2** [Minor] `live-wiring-unpinned` (kind: defect) No static check pins PARLEY_LIVE_COUCH_DATA_HOME in the check-couch-actors-live recipe
