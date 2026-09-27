---
gate: boundary-review
issue: 276
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-25T22:39:33-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Launcher accepts demo locations that enable repo mode
          detail: 'parley_app:9–14 rejects only this checkout''s descendants, while lua/parley/starter.lua:171 detects a .parley marker in the accepted cwd or its ancestors. Both cases reproduced through the launcher and production detector. The family covers markers in the demo or any ancestor, for both PARLEY_DEMO_DIR and cache-derived defaults. Explicitly enforce non-repo startup or reject marked ancestry, and add regression tests crossing the launcher/detection boundary plus a successful unmarked override. ARCH-PURPOSE: the promised non-repo app experience is not enforced.'
          family: enforce-non-repo-launch
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-25T22:52:49-07:00"
      agent: codex
      recipe: small-diff-review
      blocked: true
      protocol_error: no valid findings block
    - "n": 3
      timestamp: "2026-09-25T22:56:44-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: parley_app:56 exports PARLEY_REPO_MODE=0 and lua/parley/starter.lua:174–178 honors it. All six default/alternate and unmarked/demo-marker/ancestor-marker cases pass. Removing the launcher export in a pinned scratch snapshot makes all four marked cases fail with “demo entered repo mode.”
          round: 3
      findings:
        - id: BR-2
          severity: Minor
          title: Generated review artifact contains trailing whitespace
          detail: workshop/plans/000276-local-app-launcher-close-review.md:33 is the sole instance reported by git diff --check across this window. Remove the trailing spaces when the review artifact is next regenerated.
          family: whitespace-clean-review-artifacts
          round: 3
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#276 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-25T22:39:33-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `enforce-non-repo-launch` Launcher accepts demo locations that enable repo mode
  parley_app:9–14 rejects only this checkout's descendants, while lua/parley/starter.lua:171 detects a .parley marker in the accepted cwd or its ancestors. Both cases reproduced through the launcher and production detector. The family covers markers in the demo or any ancestor, for both PARLEY_DEMO_DIR and cache-derived defaults. Explicitly enforce non-repo startup or reject marked ancestry, and add regression tests crossing the launcher/detection boundary plus a successful unmarked override. ARCH-PURPOSE: the promised non-repo app experience is not enforced.

## Round 2 — 2026-09-25T22:52:49-07:00 (codex) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 3 — 2026-09-25T22:56:44-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — parley_app:56 exports PARLEY_REPO_MODE=0 and lua/parley/starter.lua:174–178 honors it. All six default/alternate and unmarked/demo-marker/ancestor-marker cases pass. Removing the launcher export in a pinned scratch snapshot makes all four marked cases fail with “demo entered repo mode.”

### Raised

- **BR-2** [Minor] `whitespace-clean-review-artifacts` Generated review artifact contains trailing whitespace
  workshop/plans/000276-local-app-launcher-close-review.md:33 is the sole instance reported by git diff --check across this window. Remove the trailing spaces when the review artifact is next regenerated.

## Open findings

- **BR-2** [Minor] `whitespace-clean-review-artifacts` Generated review artifact contains trailing whitespace
