---
gate: boundary-review
issue: 336
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 60238089-c04f-4a99-a6c9-32c929b28ce4
            repository: github.com/xianxu/parley.nvim
            issue_id: "000336"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d38bcd8bd61a81eb
            reviewed_head: 00221b88dc4012d833acf04d2d14012e8e19b00e
            slot: parley.nvim:3
            requested_at: "2026-10-15T22:58:47.635331Z"
          phase: finished
          pid: 94669
          started_at: "2026-10-15T22:58:48.131766Z"
          finished_at: "2026-10-15T23:01:58.562967Z"
          session_id: 6df3d759-2d5b-47a8-9d2c-93fbda2d5324
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 00221b88dc4012d833acf04d2d14012e8e19b00e
        tracker_head: a18afae87d8073e54f6dbd63cceadb5c6ed1dd73
        branch_point: 35d876d55d7940f20c3d6087846f4247d2b9b14d
        since: "2026-10-15T15:41:39-07:00"
        until: "2026-10-15T15:58:10-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T15:41:39-07:00"
              end: "2026-10-15T15:58:10-07:00"
              began: "2026-10-15T15:41:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b23727413062198c58c9da65bf7765edd3fca8c6e8d35c575df067c7d459d1fb
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 912973
              windows:
                - start: "2026-10-15T15:41:39-07:00"
                  end: "2026-10-15T15:58:10-07:00"
      "n": 1
      timestamp: "2026-10-15T16:02:01-07:00"
      dispatched: "2026-10-15T15:58:47-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Picker-settle half of the fix has no test that fails without it
          detail: 'Deleting the settle block (wait for the reopened picker, then send Esc) at tests/packaging/vm_chat.lua:126-136 leaves the focused packaging_vm_spec green (17/0, two runs). The guest no-float assertion at tests/integration/packaging_vm_spec.lua:156 runs synchronously after run() returns, so a picker reopen still queued in vim.schedule is never seen. Done-when clause 2 ("settles the reopened picker before chat dispatch") is therefore unpinned. Fix: yield the event loop (vim.wait for a bounded window) before asserting no floating window, or assert it in the probe after ask() following a yield, then confirm the revert goes red. This is the only instance of this family in the window.'
          family: fix-without-failing-regression
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: maparg Esc callback is invoked without checking it exists
          detail: tests/packaging/vm_chat.lua:133 calls maparg('<Esc>','n',false,true).callback() directly. The sibling <CR> lookup at :121-122 checks the type first. The existing <Down> call at :120 has the same gap.
          family: unguarded-keymap-callback
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#336 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T16:02:01-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `fix-without-failing-regression` (kind: defect) Picker-settle half of the fix has no test that fails without it
  Deleting the settle block (wait for the reopened picker, then send Esc) at tests/packaging/vm_chat.lua:126-136 leaves the focused packaging_vm_spec green (17/0, two runs). The guest no-float assertion at tests/integration/packaging_vm_spec.lua:156 runs synchronously after run() returns, so a picker reopen still queued in vim.schedule is never seen. Done-when clause 2 ("settles the reopened picker before chat dispatch") is therefore unpinned. Fix: yield the event loop (vim.wait for a bounded window) before asserting no floating window, or assert it in the probe after ask() following a yield, then confirm the revert goes red. This is the only instance of this family in the window.
- **BR-2** [Minor] `unguarded-keymap-callback` (kind: defect) maparg Esc callback is invoked without checking it exists
  tests/packaging/vm_chat.lua:133 calls maparg('<Esc>','n',false,true).callback() directly. The sibling <CR> lookup at :121-122 checks the type first. The existing <Down> call at :120 has the same gap.

## Open findings

- **BR-1** [Important] `fix-without-failing-regression` (kind: defect) Picker-settle half of the fix has no test that fails without it
- **BR-2** [Minor] `unguarded-keymap-callback` (kind: defect) maparg Esc callback is invoked without checking it exists
