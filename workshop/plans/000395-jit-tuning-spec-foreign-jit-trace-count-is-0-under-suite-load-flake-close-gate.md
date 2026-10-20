---
gate: boundary-review
issue: 395
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b4f8644a-331b-49da-993d-554c8cee2ac9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000395"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/6297bbbcdb7ffa4d
            reviewed_head: f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66
            slot: parley.nvim:3
            requested_at: "2026-10-20T02:46:10.635475Z"
          phase: finished
          pid: 44164
          started_at: "2026-10-20T02:46:10.868561Z"
          finished_at: "2026-10-20T02:52:14.106756Z"
          session_id: a1f06a1e-a2ea-4725-acc1-06a957d2bcee
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66
        tracker_head: 83f37379b165bfb36d10903e78a38b826f9963c7
        branch_point: 877d904c4a29b424734a845e2a863edaba152deb
        since: "2026-10-19T19:32:05-07:00"
        until: "2026-10-19T19:45:31-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T19:32:05-07:00"
              end: "2026-10-19T19:45:31-07:00"
              began: "2026-10-19T19:32:05-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 708a8631ede4c3c8a4f00fa8866b77aa2acf6216f3ed3cc1b69db6f7dba8a9f4
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 11793424
              windows:
                - start: "2026-10-19T19:32:05-07:00"
                  end: "2026-10-19T19:45:31-07:00"
      "n": 1
      timestamp: "2026-10-19T19:52:14-07:00"
      dispatched: "2026-10-19T19:46:10-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Sibling child-VM oracle document_sequence_spec.lua:697 asserts compiled > 0 with no mcode-allocation exemption
          detail: |-
            Same flake class as this issue: on the installed LuaJIT 0.11.7 under load, every trace can abort with
            'failed to allocate mcode memory', so compiled stays 0. It is the only other instance in the tree.
            Consider the same id-set tracking plus #294 abort classification there.
          family: jit-trace-oracle-ignores-mcode-defect
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The unplaceable (#294) exemption predicate at jit_tuning_spec.lua:145-149 is reached only under real load
          detail: |-
            No deterministic fixture exercises the exemption. If the text drifts, the failure is safe (the flake returns,
            the test does not wrongly pass), but the classification is unpinned. It is the only such predicate in this window.
          family: exemption-branch-without-fixture
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: The Done-when clause about a loaded full suite is evidenced by a 120-way child-script stress, not a full-suite run
          detail: |-
            The Log records stress runs and isolated make test-spec runs on both runtimes. No loaded full-suite pass is
            recorded. Acceptable as a proxy; noted for the close record.
          family: done-when-evidence-proxy
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c9b2349a-e256-4734-8b8c-c699526d0e02
            repository: github.com/xianxu/parley.nvim
            issue_id: "000395"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/5b837d3d6d089701
            reviewed_head: 79d1cbd13dbe865767200a65aa3cf374d2919e80
            slot: parley.nvim:3
            requested_at: "2026-10-20T03:10:18.552403Z"
          phase: finished
          pid: 91588
          started_at: "2026-10-20T03:10:18.812845Z"
          finished_at: "2026-10-20T03:18:01.214176Z"
          session_id: a8595b15-95a1-4a7e-ad4c-309569412c5c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 79d1cbd13dbe865767200a65aa3cf374d2919e80
        tracker_head: 4ba38c55dc1da1ec577889cd4c1dbb33d276f75f
        branch_point: 877d904c4a29b424734a845e2a863edaba152deb
        since: "2026-10-19T19:32:05-07:00"
        until: "2026-10-19T20:09:36-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T19:32:05-07:00"
              end: "2026-10-19T20:09:36-07:00"
              began: "2026-10-19T19:32:05-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b873a795a184b575dc0d924a6f5da27f89cb882e215678ccc39aaa4f675b34bd
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 12121112
              windows:
                - start: "2026-10-19T19:32:05-07:00"
                  end: "2026-10-19T20:09:36-07:00"
        cuts:
            - dispatched: "2026-10-19T19:46:10-07:00"
              finalized: "2026-10-19T19:52:14-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-19T20:18:02-07:00"
      dispatched: "2026-10-19T20:10:18-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: document_sequence_spec.lua:703-714 retries up to 3 fresh VMs only on Oracle.mcode_blocked, and compiled > 0 is still asserted; a local run reproduced a 0-compiled defect VM that the predicate classifies correctly.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The predicate moved to tests/helpers/jit_oracle.lua, and tests/unit/jit_oracle_spec.lua pins it without load, plus the error text against jit.vmdef.traceerr. Both consumers derive from it.
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: Still Minor and non-blocking. No loaded full-suite pass is recorded, and the sibling's residual failure rate with retries is unmeasured (1 of 6 unloaded runs were defect VMs locally).
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: The abort-reason decode is copy-pasted into both child-VM trace hooks instead of living in jit_oracle
          detail: jit_tuning_spec.lua:102-103 and document_sequence_spec.lua:668-669 hold the same traceerr[otr]/format(oex) logic. A jit_oracle.abort_reason(otr, oex) helper, required from the child (whose cwd is the repo root), would make it one source.
          family: shared-helper-partial-extraction
          round: 2
      recipe: fix-review
      isolation: checkout
      reviewed: 79d1cbd13dbe865767200a65aa3cf374d2919e80
      blocked: false
---

# Gate ledger — parley.nvim#395 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T19:52:14-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `jit-trace-oracle-ignores-mcode-defect` (kind: defect) Sibling child-VM oracle document_sequence_spec.lua:697 asserts compiled > 0 with no mcode-allocation exemption
  Same flake class as this issue: on the installed LuaJIT 0.11.7 under load, every trace can abort with
  'failed to allocate mcode memory', so compiled stays 0. It is the only other instance in the tree.
  Consider the same id-set tracking plus #294 abort classification there.
- **BR-2** [Minor] `exemption-branch-without-fixture` (kind: defect) The unplaceable (#294) exemption predicate at jit_tuning_spec.lua:145-149 is reached only under real load
  No deterministic fixture exercises the exemption. If the text drifts, the failure is safe (the flake returns,
  the test does not wrongly pass), but the classification is unpinned. It is the only such predicate in this window.
- **BR-3** [Minor] `done-when-evidence-proxy` (kind: defect) The Done-when clause about a loaded full suite is evidenced by a 120-way child-script stress, not a full-suite run
  The Log records stress runs and isolated make test-spec runs on both runtimes. No loaded full-suite pass is
  recorded. Acceptable as a proxy; noted for the close record.

## Round 2 — 2026-10-19T20:18:02-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — document_sequence_spec.lua:703-714 retries up to 3 fresh VMs only on Oracle.mcode_blocked, and compiled > 0 is still asserted; a local run reproduced a 0-compiled defect VM that the predicate classifies correctly.
- BR-2 — addressed — The predicate moved to tests/helpers/jit_oracle.lua, and tests/unit/jit_oracle_spec.lua pins it without load, plus the error text against jit.vmdef.traceerr. Both consumers derive from it.
- BR-3 — not-addressed — Still Minor and non-blocking. No loaded full-suite pass is recorded, and the sibling's residual failure rate with retries is unmeasured (1 of 6 unloaded runs were defect VMs locally).

### Raised

- **BR-4** [Minor] `shared-helper-partial-extraction` (kind: defect) The abort-reason decode is copy-pasted into both child-VM trace hooks instead of living in jit_oracle
  jit_tuning_spec.lua:102-103 and document_sequence_spec.lua:668-669 hold the same traceerr[otr]/format(oex) logic. A jit_oracle.abort_reason(otr, oex) helper, required from the child (whose cwd is the repo root), would make it one source.

## Open findings

- **BR-3** [Minor] `done-when-evidence-proxy` (kind: defect) The Done-when clause about a loaded full suite is evidenced by a 120-way child-script stress, not a full-suite run
- **BR-4** [Minor] `shared-helper-partial-extraction` (kind: defect) The abort-reason decode is copy-pasted into both child-VM trace hooks instead of living in jit_oracle
