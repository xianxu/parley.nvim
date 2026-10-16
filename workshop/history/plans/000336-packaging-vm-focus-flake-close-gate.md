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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 3e3d67fb-4aa1-4947-9408-620cb6dc89c9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000336"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1e411a8717f267e7
            reviewed_head: 01ebf08816a07f290c4382c016fc195792b43c19
            slot: parley.nvim:3
            requested_at: "2026-10-15T23:08:18.663769Z"
          phase: finished
          pid: 54092
          started_at: "2026-10-15T23:08:18.767704Z"
          finished_at: "2026-10-15T23:10:35.918953Z"
          session_id: 28c82759-0ee7-42c5-965e-f7a19479ab88
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 01ebf08816a07f290c4382c016fc195792b43c19
        tracker_head: 6f33900280b5db51d9e67071bc320b62987aacec
        branch_point: 35d876d55d7940f20c3d6087846f4247d2b9b14d
        since: "2026-10-15T15:41:39-07:00"
        until: "2026-10-15T16:05:17-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T15:41:39-07:00"
              end: "2026-10-15T16:05:17-07:00"
              began: "2026-10-15T15:41:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: bf0caa972dabdf501dd111cf10127e6d8064ac97dbb95d2b12b9dcc567dc80ac
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 1077960
              windows:
                - start: "2026-10-15T15:41:39-07:00"
                  end: "2026-10-15T16:05:17-07:00"
        cuts:
            - dispatched: "2026-10-15T15:58:47-07:00"
              finalized: "2026-10-15T16:02:01-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T16:10:43-07:00"
      dispatched: "2026-10-15T16:08:18-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Reverted settle block in disposable checkout; focused packaging_vm_spec went 16/1 twice (vm_chat.lua:45 "chat dispatch began while account connection was still open"); restored 17/0.
          round: 2
        - id: BR-2
          disposition: addressed
          note: All three maparg presses (Down, CR, Esc) now go through press() at vm_chat.lua:35-39, which asserts a callback exists; no other unguarded instance in the window.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 01ebf08816a07f290c4382c016fc195792b43c19
      blocked: false
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

## Round 2 — 2026-10-15T16:10:43-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Reverted settle block in disposable checkout; focused packaging_vm_spec went 16/1 twice (vm_chat.lua:45 "chat dispatch began while account connection was still open"); restored 17/0.
- BR-2 — addressed — All three maparg presses (Down, CR, Esc) now go through press() at vm_chat.lua:35-39, which asserts a callback exists; no other unguarded instance in the window.

## Open findings

(none — every finding has been disposed)
