---
reviewer_runs:
    - version: 1
      intent:
        id: fe1c78e5-dae7-4d0b-9a01-490c2aac60f4
        repository: github.com/xianxu/parley.nvim
        issue_id: "000353"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        reviewed_head: c56e5126dfdb1bc32b7681f2437ac4920cf0ad28
        slot: parley.nvim:2
        requested_at: "2026-10-16T21:40:13.639639Z"
      phase: finished
      pid: 53300
      started_at: "2026-10-16T21:40:13.802001Z"
      finished_at: "2026-10-16T21:40:36.559258Z"
      session_id: 01a146a8-8ea9-7da2-8c99-990e5095f411
      outcome: returned
gate: plan-quality
issue: 353
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 6d9051f4-7e44-4328-a04a-cf8961283029
            repository: github.com/xianxu/parley.nvim
            issue_id: "000353"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
            reviewed_head: 04030a663f3bed09667bb7818160d05a8ee09023
            slot: parley.nvim:2
            requested_at: "2026-10-16T21:36:55.08015Z"
          phase: finished
          pid: 44392
          started_at: "2026-10-16T21:36:55.253937Z"
          finished_at: "2026-10-16T21:37:31.392804Z"
          session_id: 01a146a5-88d1-7b70-b972-10b8f28c5a48
          outcome: returned
      "n": 1
      timestamp: "2026-10-16T14:37:31-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Define destination Back history for cross-window follows
          detail: Plan lines 47–48 install the origin trail in the actual destination while retaining native history behavior, but existing Back traverses only that destination's earlier visits. Following from A into an already-visible B can therefore display A › B while Back goes to unrelated X or has no target. Under ARCH-PURPOSE and ARCH-ORDER, specify the atomic destination-history transition, cursor ownership and treatment of its prior history so Back follows the displayed ancestry; apply the same coherence rule to every cross-window landing, as the restore revision already does for restored trails.
          family: trail-history-coherence
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace test-case inventories with named functions and adversarial strategies
          detail: Plan lines 83–84, 92–94, 101–102 and 130 enumerate prose test cases, while the new breadcrumb transition, display projection and history reconstruction functions are not named. Compress these inventories into the functions to be unit-tested plus one strategy line per risky function naming its adversarial input class and mechanical guard; retain integration seams and verification commands. Include generated event-sequence invariants for history/trail coherence and property-based width/input validation for projection and restore.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: 9ad24afa-244e-4506-a163-14a78dd9dd3e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000353"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
            reviewed_head: c56e5126dfdb1bc32b7681f2437ac4920cf0ad28
            slot: parley.nvim:2
            requested_at: "2026-10-16T21:38:24.630758Z"
          phase: finished
          pid: 47864
          started_at: "2026-10-16T21:38:24.776726Z"
          finished_at: "2026-10-16T21:39:13.241294Z"
          session_id: 01a146a6-e49e-74f2-9a15-f853d20aaa03
          outcome: returned
      "n": 2
      timestamp: "2026-10-16T14:39:13-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: One install_trail transition reconstructs destination Back ancestry for all follows and restores, with explicit overlap, cursor, cap and atomic commit rules.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: The superseding strategy table names production functions and generated adversarial checks for history coherence, projection widths and restore validation.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: 2ff2fefe-01f5-403d-8150-a94639877861
            repository: github.com/xianxu/parley.nvim
            issue_id: "000353"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
            reviewed_head: c56e5126dfdb1bc32b7681f2437ac4920cf0ad28
            slot: parley.nvim:2
            requested_at: "2026-10-16T21:39:49.412582Z"
          phase: finished
          pid: 51396
          started_at: "2026-10-16T21:39:49.563434Z"
          finished_at: "2026-10-16T21:40:11.607968Z"
          session_id: 01a146a8-2fcb-70a1-be84-67e9861da666
          outcome: returned
      "n": 3
      timestamp: "2026-10-16T14:40:11-07:00"
      agent: codex
      blocked: false
content_hash: dc3114fabd8904ef92efa2e89f794788a90d8e1a594de773daba2261aeb3d7ab
---

# Gate ledger — parley.nvim#353 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T14:37:31-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `trail-history-coherence` Define destination Back history for cross-window follows
  Plan lines 47–48 install the origin trail in the actual destination while retaining native history behavior, but existing Back traverses only that destination's earlier visits. Following from A into an already-visible B can therefore display A › B while Back goes to unrelated X or has no target. Under ARCH-PURPOSE and ARCH-ORDER, specify the atomic destination-history transition, cursor ownership and treatment of its prior history so Back follows the displayed ancestry; apply the same coherence rule to every cross-window landing, as the restore revision already does for restored trails.
- **PQ-2** [Important] `function-level-test-strategy` Replace test-case inventories with named functions and adversarial strategies
  Plan lines 83–84, 92–94, 101–102 and 130 enumerate prose test cases, while the new breadcrumb transition, display projection and history reconstruction functions are not named. Compress these inventories into the functions to be unit-tested plus one strategy line per risky function naming its adversarial input class and mechanical guard; retain integration seams and verification commands. Include generated event-sequence invariants for history/trail coherence and property-based width/input validation for projection and restore.

## Round 2 — 2026-10-16T14:39:13-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — One install_trail transition reconstructs destination Back ancestry for all follows and restores, with explicit overlap, cursor, cap and atomic commit rules.
- PQ-2 — addressed — The superseding strategy table names production functions and generated adversarial checks for history coherence, projection widths and restore validation.

## Round 3 — 2026-10-16T14:40:11-07:00 (codex) — passed

## Open findings

(none — every finding has been disposed)
