---
gate: boundary-review
issue: 313
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-10T13:15:14-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: A late couch exit can rewrite the lock after the turn has moved on (unlock and resubmit, or the agent already replied)
          detail: 'The vim.system callback in M.submit checks only state[buf]. A failing exit from an earlier submit calls fail(), which writes holder: operator and makes the buffer editable during a later agent turn. Guard it with a per-submit generation number plus read_turn == agent, and add a spec with a delayed failing fake.'
          family: stale-async-completion-guard
          round: 1
        - id: BR-2
          severity: Important
          title: In the free state the buffer can be stale, so the first keystroke takes the turn on outdated content and submit can overwrite the agent's rewrite
          detail: autoread only reloads on checktime triggers (focus, buffer enter), not when the file changes on disk. Run checktime before write_lock(operator), or watch the file in the free state, and add a spec that rewrites the file on disk while free and then edits.
          family: free-state-disk-staleness
          round: 1
        - id: BR-3
          severity: Minor
          title: restart_idle reads the lock file and recreates a uv timer on every TextChangedI
          family: per-keystroke-io
          round: 1
        - id: BR-4
          severity: Minor
          title: The plan's Core-concepts prose still describes vim.b idempotency, the eol extmark reminder and the old unlock-keeps-lock behaviour
          family: plan-text-drift
          round: 1
        - id: BR-5
          severity: Minor
          title: 'A buffer reopened with an existing holder: operator lock never starts the idle timer, so it shows "your turn" instead of "stale" until the next edit'
          family: idle-timer-on-attach
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#313 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-10T13:15:14-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `stale-async-completion-guard` A late couch exit can rewrite the lock after the turn has moved on (unlock and resubmit, or the agent already replied)
  The vim.system callback in M.submit checks only state[buf]. A failing exit from an earlier submit calls fail(), which writes holder: operator and makes the buffer editable during a later agent turn. Guard it with a per-submit generation number plus read_turn == agent, and add a spec with a delayed failing fake.
- **BR-2** [Important] `free-state-disk-staleness` In the free state the buffer can be stale, so the first keystroke takes the turn on outdated content and submit can overwrite the agent's rewrite
  autoread only reloads on checktime triggers (focus, buffer enter), not when the file changes on disk. Run checktime before write_lock(operator), or watch the file in the free state, and add a spec that rewrites the file on disk while free and then edits.
- **BR-3** [Minor] `per-keystroke-io` restart_idle reads the lock file and recreates a uv timer on every TextChangedI
- **BR-4** [Minor] `plan-text-drift` The plan's Core-concepts prose still describes vim.b idempotency, the eol extmark reminder and the old unlock-keeps-lock behaviour
- **BR-5** [Minor] `idle-timer-on-attach` A buffer reopened with an existing holder: operator lock never starts the idle timer, so it shows "your turn" instead of "stale" until the next edit

## Open findings

- **BR-1** [Important] `stale-async-completion-guard` A late couch exit can rewrite the lock after the turn has moved on (unlock and resubmit, or the agent already replied)
- **BR-2** [Important] `free-state-disk-staleness` In the free state the buffer can be stale, so the first keystroke takes the turn on outdated content and submit can overwrite the agent's rewrite
- **BR-3** [Minor] `per-keystroke-io` restart_idle reads the lock file and recreates a uv timer on every TextChangedI
- **BR-4** [Minor] `plan-text-drift` The plan's Core-concepts prose still describes vim.b idempotency, the eol extmark reminder and the old unlock-keeps-lock behaviour
- **BR-5** [Minor] `idle-timer-on-attach` A buffer reopened with an existing holder: operator lock never starts the idle timer, so it shows "your turn" instead of "stale" until the next edit
