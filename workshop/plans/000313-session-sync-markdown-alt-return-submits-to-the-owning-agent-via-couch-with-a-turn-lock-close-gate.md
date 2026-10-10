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
    - "n": 2
      timestamp: "2026-10-10T13:24:43-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Generation + state identity + read_turn==agent guard (session_sync.lua:337-349), unlock bumps gen; spec "a late failing exit..." passes.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Free-turn watch reloads unmodified buffer; submit refuses when disk_changed; specs for both pass (auto-save sibling raised as Minor).
          round: 2
        - id: BR-3
          disposition: addressed
          note: restart_idle uses cached s.turn and reuses one timer; first-edit read_turn short-circuits behind s.turn=="free".
          round: 2
        - id: BR-4
          disposition: addressed
          note: Plan Revisions "close review round 1" supersedes the vim.b / extmark / unlock prose (append-only convention).
          round: 2
        - id: BR-5
          disposition: addressed
          note: attach now calls restart_idle; spec "a file reopened during an operator turn still turns stale" passes.
          round: 2
      findings:
        - id: BR-6
          severity: Minor
          title: The markdown auto-save (init.lua:1818) can write a stale copy, which bypasses submit's disk_changed guard
          detail: '2nd finding in this family. Rule: the operator''s turn must never start on a copy older than the file on disk. When taking the turn, refuse the lock (reload or undo) when disk_changed instead of warning, so every writer (submit, auto-save, :w) is safe without its own guard.'
          family: free-state-disk-staleness
          round: 2
        - id: BR-7
          severity: Minor
          title: 'The atlas still says the lock is polled only during the agent''s turn and that operator: is recorded as the lock holder'
          detail: '2nd finding in this family. Rule: a behaviour fix updates every place that restates that behaviour (module header, plan Revisions, atlas) in the same commit. The free-turn reload and the submit refusal are missing from atlas/modes/session_sync.md.'
          family: plan-text-drift
          round: 2
      recipe: milestone-review
      reviewed: 706d9f61858374f48d4f69e59bc87b9f87d77f05
      blocked: false
    - "n": 3
      timestamp: "2026-10-10T13:28:37-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: addressed
          note: First-edit guard now reloads instead of taking the lock when disk_changed (session_sync.lua:268-281); regression test at integration spec :186 fails on the old lock-then-warn code.
          round: 3
        - id: BR-7
          disposition: addressed
          note: 'atlas/modes/session_sync.md now describes the watch outside the operator turn, the free-turn reload, the stale first-edit reload and submit refusal; operator: no longer called the lock holder.'
          round: 3
      recipe: milestone-review
      reviewed: df3b00d600c47b9de78854214616b922db7d5a67
      blocked: false
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

## Round 2 — 2026-10-10T13:24:43-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Generation + state identity + read_turn==agent guard (session_sync.lua:337-349), unlock bumps gen; spec "a late failing exit..." passes.
- BR-2 — addressed — Free-turn watch reloads unmodified buffer; submit refuses when disk_changed; specs for both pass (auto-save sibling raised as Minor).
- BR-3 — addressed — restart_idle uses cached s.turn and reuses one timer; first-edit read_turn short-circuits behind s.turn=="free".
- BR-4 — addressed — Plan Revisions "close review round 1" supersedes the vim.b / extmark / unlock prose (append-only convention).
- BR-5 — addressed — attach now calls restart_idle; spec "a file reopened during an operator turn still turns stale" passes.

### Raised

- **BR-6** [Minor] `free-state-disk-staleness` The markdown auto-save (init.lua:1818) can write a stale copy, which bypasses submit's disk_changed guard
  2nd finding in this family. Rule: the operator's turn must never start on a copy older than the file on disk. When taking the turn, refuse the lock (reload or undo) when disk_changed instead of warning, so every writer (submit, auto-save, :w) is safe without its own guard.
- **BR-7** [Minor] `plan-text-drift` The atlas still says the lock is polled only during the agent's turn and that operator: is recorded as the lock holder
  2nd finding in this family. Rule: a behaviour fix updates every place that restates that behaviour (module header, plan Revisions, atlas) in the same commit. The free-turn reload and the submit refusal are missing from atlas/modes/session_sync.md.

## Round 3 — 2026-10-10T13:28:37-07:00 (claude) — passed

### Disposed

- BR-6 — addressed — First-edit guard now reloads instead of taking the lock when disk_changed (session_sync.lua:268-281); regression test at integration spec :186 fails on the old lock-then-warn code.
- BR-7 — addressed — atlas/modes/session_sync.md now describes the watch outside the operator turn, the free-turn reload, the stale first-edit reload and submit refusal; operator: no longer called the lock holder.

## Open findings

(none — every finding has been disposed)
