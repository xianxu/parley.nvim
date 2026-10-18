---
gate: boundary-review
issue: 381
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c1adf78d-20d4-4558-97dc-52518d8b7210
            repository: github.com/xianxu/parley.nvim
            issue_id: "000381"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/46b50fb03b13ee79
            reviewed_head: 74f9a4582ba9608a5bcd2648f6879951fb29b089
            slot: parley.nvim:4
            requested_at: "2026-10-18T01:35:27.87627Z"
          phase: finished
          pid: 81263
          started_at: "2026-10-18T01:35:27.96949Z"
          finished_at: "2026-10-18T01:37:17.665019Z"
          session_id: aeb6da83-7251-49ab-9215-f79ead0d23c4
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 74f9a4582ba9608a5bcd2648f6879951fb29b089
        tracker_head: 643d6d521ab8a00d4f37cbe0bb4c59b5e909c8ba
        branch_point: 4ce9f053e48c7cf23dda4d394f9705a6c6e7d56e
        since: "2026-10-17T18:13:34-07:00"
        until: "2026-10-17T18:35:03-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T18:13:34-07:00"
              end: "2026-10-17T18:35:03-07:00"
              began: "2026-10-17T18:13:34-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 0dd0d1b19f3212c1be5c332f4055be5ef6706d7eb6d8402c7bd3c6b254cdffa7
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 38449975
              windows:
                - start: "2026-10-17T18:13:34-07:00"
                  end: "2026-10-17T18:35:03-07:00"
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
      "n": 1
      timestamp: "2026-10-17T18:37:19-07:00"
      dispatched: "2026-10-17T18:35:27-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: The fixed-/tmp guard only matches the exact spellings that were swept
          detail: 'FIXED_TMP in tests/arch/scratch_placement_spec.lua:88-91 matches dir=''/tmp'' and mktemp ... /tmp/. It misses these spellings of the same class: Python dir=''/tmp/'' (trailing slash), dir=Path(''/tmp''), dir=''/tmp/sub''; shell mktemp -p /tmp and mktemp --tmpdir=/tmp; Lua writes under a literal /tmp, which the plan''s sweep covered but the guard does not scan. The tree has none of these today. Broadening both patterns and adding one fixture line per spelling would close the gap.'
          family: fixed-tmp-temp-root
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 74f9a4582ba9608a5bcd2648f6879951fb29b089
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4124250a-7ed5-4eeb-9f5c-272df4f70272
            repository: github.com/xianxu/parley.nvim
            issue_id: "000381"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/03d18069c602a4ab
            reviewed_head: 105a962570783575e9bdd540b6e6cedb37547f06
            slot: parley.nvim:4
            requested_at: "2026-10-18T01:41:14.08744Z"
          phase: finished
          pid: 25545
          started_at: "2026-10-18T01:41:14.469804Z"
          finished_at: "2026-10-18T01:43:54.14943Z"
          session_id: 00e49820-77af-431d-8063-bad951c99124
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 105a962570783575e9bdd540b6e6cedb37547f06
        tracker_head: 802d8fa76071381b05d331033b93c59f1e52b99d
        branch_point: 4ce9f053e48c7cf23dda4d394f9705a6c6e7d56e
        since: "2026-10-17T18:13:34-07:00"
        until: "2026-10-17T18:40:51-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T18:13:34-07:00"
              end: "2026-10-17T18:40:51-07:00"
              began: "2026-10-17T18:13:34-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cbcacf94ac25e44985eda156bd2fea2b7a443899ba74b666882ae9eb28c7e240
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 38598875
              windows:
                - start: "2026-10-17T18:13:34-07:00"
                  end: "2026-10-17T18:40:51-07:00"
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
        cuts:
            - dispatched: "2026-10-17T18:35:27-07:00"
              finalized: "2026-10-17T18:37:19-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-17T18:43:57-07:00"
      dispatched: "2026-10-17T18:41:14-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Every listed spelling (py dir='/tmp/', '/tmp/sub', Path('/tmp'); sh -p, --tmpdir=; lua io.open/mkdir/writefile) now has a FIXED_TMP rule and a fixture line; both guard cases pass under make test-spec at the pinned head.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Minor
          title: Language scoping stops the shell mktemp rules from scanning shell commands inside Lua or Python
          detail: 'This is the 2nd finding in family fixed-tmp-temp-root. lang_of (scratch_placement_spec.lua:102-114) sends .lua and .py files only to their own language''s rules. So vim.fn.system("mktemp -d /tmp/...") or subprocess mktemp -p /tmp now gets past the guard, though it was caught before this interdiff (prevalence today: 0 in the tree). The rule that covers the class: scope a pattern by file type only when it would otherwise give false positives (the Python dir= keyword). Shell command patterns stay unscoped, because those commands can appear inside any language. Add one fixture line for embedded mktemp.'
          family: fixed-tmp-temp-root
          round: 2
      recipe: fix-review
      isolation: fenced
      reviewed: 105a962570783575e9bdd540b6e6cedb37547f06
      blocked: false
---

# Gate ledger — parley.nvim#381 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T18:37:19-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `fixed-tmp-temp-root` (kind: defect) The fixed-/tmp guard only matches the exact spellings that were swept
  FIXED_TMP in tests/arch/scratch_placement_spec.lua:88-91 matches dir='/tmp' and mktemp ... /tmp/. It misses these spellings of the same class: Python dir='/tmp/' (trailing slash), dir=Path('/tmp'), dir='/tmp/sub'; shell mktemp -p /tmp and mktemp --tmpdir=/tmp; Lua writes under a literal /tmp, which the plan's sweep covered but the guard does not scan. The tree has none of these today. Broadening both patterns and adding one fixture line per spelling would close the gap.

## Round 2 — 2026-10-17T18:43:57-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Every listed spelling (py dir='/tmp/', '/tmp/sub', Path('/tmp'); sh -p, --tmpdir=; lua io.open/mkdir/writefile) now has a FIXED_TMP rule and a fixture line; both guard cases pass under make test-spec at the pinned head.

### Raised

- **BR-2** [Minor] `fixed-tmp-temp-root` (kind: defect) Language scoping stops the shell mktemp rules from scanning shell commands inside Lua or Python
  This is the 2nd finding in family fixed-tmp-temp-root. lang_of (scratch_placement_spec.lua:102-114) sends .lua and .py files only to their own language's rules. So vim.fn.system("mktemp -d /tmp/...") or subprocess mktemp -p /tmp now gets past the guard, though it was caught before this interdiff (prevalence today: 0 in the tree). The rule that covers the class: scope a pattern by file type only when it would otherwise give false positives (the Python dir= keyword). Shell command patterns stay unscoped, because those commands can appear inside any language. Add one fixture line for embedded mktemp.

## Open findings

- **BR-2** [Minor] `fixed-tmp-temp-root` (kind: defect) Language scoping stops the shell mktemp rules from scanning shell commands inside Lua or Python
