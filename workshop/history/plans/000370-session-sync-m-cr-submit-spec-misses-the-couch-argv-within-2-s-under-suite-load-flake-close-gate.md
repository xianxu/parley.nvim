---
gate: boundary-review
issue: 370
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 1fda3208-c291-4e15-a620-48b03e1ffedd
            repository: github.com/xianxu/parley.nvim
            issue_id: "000370"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f19d23343146ee3c
            reviewed_head: d0d574ff658a3cf5a0f513957cd91564857f72dd
            slot: parley.nvim:3
            requested_at: "2026-10-17T09:55:15.47786Z"
          phase: finished
          pid: 36846
          started_at: "2026-10-17T09:55:15.673573Z"
          finished_at: "2026-10-17T09:57:49.346573Z"
          session_id: ca2e957f-12f7-4f62-a851-d23dbb1d9ff3
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d0d574ff658a3cf5a0f513957cd91564857f72dd
        tracker_head: 70c0827c9ee5be56d96d1e41d00308eb0a68e1e8
        branch_point: d104447797a74f52477481a8d2b5ddd6d7a6091d
        since: "2026-10-17T02:49:00-07:00"
        until: "2026-10-17T02:54:36-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T02:49:00-07:00"
              end: "2026-10-17T02:54:36-07:00"
              began: "2026-10-17T02:49:00-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b288ae475620b8d70cf81e88d34e71f200fe086e15d81818e00a33eaef6aa0d2
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 22837531
              windows:
                - start: "2026-10-17T02:49:00-07:00"
                  end: "2026-10-17T02:54:36-07:00"
      "n": 1
      timestamp: "2026-10-17T02:57:50-07:00"
      dispatched: "2026-10-17T02:55:15-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: arrival_ms() copies agentic_document config_ms fallback without its number/positive guard
          detail: 'tests/integration/session_sync_spec.lua:16-18 copies lua/parley/agentic_document.lua:105-109 but drops the type(value)=="number" and value>0 check. A 0 or non-number config value would make the spec wait 0 ms while the product falls back to 15000. This is the only instance in the window (ARCH-DRY). Fix: copy the guard, or expose config_ms and call it.'
          family: restated-config-fallback
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: arrival_ms comment calls the bound the Couch round-trip deadline for waits that make no Couch call
          detail: The comment at session_sync_spec.lua:12-15 says the bound is the submit's deadline for a Couch round-trip. About 20 of the 34 sites wait on watcher reloads, .clobbered files, winbar bands or ping ticks (e.g. 303, 337, 355, 384, 448, 477, 487, 539, 573, 610, 622, 636, 645, 689, 700). Reword it as a generous bound borrowed from that deadline.
          family: comment-claim-overreach
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Done-when requires the full suite to pass, but the issue records only the focused run
          detail: Done when says "the focused spec and the full suite pass". The Plan checklist and Log record only the focused 64/64 run. Record a full-suite result before closing. This review ran only the focused spec, which passed, and the revert check.
          family: done-when-clause-unevidenced
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: d0d574ff658a3cf5a0f513957cd91564857f72dd
      blocked: false
---

# Gate ledger — parley.nvim#370 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T02:57:50-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `restated-config-fallback` (kind: defect) arrival_ms() copies agentic_document config_ms fallback without its number/positive guard
  tests/integration/session_sync_spec.lua:16-18 copies lua/parley/agentic_document.lua:105-109 but drops the type(value)=="number" and value>0 check. A 0 or non-number config value would make the spec wait 0 ms while the product falls back to 15000. This is the only instance in the window (ARCH-DRY). Fix: copy the guard, or expose config_ms and call it.
- **BR-2** [Minor] `comment-claim-overreach` (kind: defect) arrival_ms comment calls the bound the Couch round-trip deadline for waits that make no Couch call
  The comment at session_sync_spec.lua:12-15 says the bound is the submit's deadline for a Couch round-trip. About 20 of the 34 sites wait on watcher reloads, .clobbered files, winbar bands or ping ticks (e.g. 303, 337, 355, 384, 448, 477, 487, 539, 573, 610, 622, 636, 645, 689, 700). Reword it as a generous bound borrowed from that deadline.
- **BR-3** [Minor] `done-when-clause-unevidenced` (kind: defect) Done-when requires the full suite to pass, but the issue records only the focused run
  Done when says "the focused spec and the full suite pass". The Plan checklist and Log record only the focused 64/64 run. Record a full-suite result before closing. This review ran only the focused spec, which passed, and the revert check.

## Open findings

- **BR-1** [Minor] `restated-config-fallback` (kind: defect) arrival_ms() copies agentic_document config_ms fallback without its number/positive guard
- **BR-2** [Minor] `comment-claim-overreach` (kind: defect) arrival_ms comment calls the bound the Couch round-trip deadline for waits that make no Couch call
- **BR-3** [Minor] `done-when-clause-unevidenced` (kind: defect) Done-when requires the full suite to pass, but the issue records only the focused run
