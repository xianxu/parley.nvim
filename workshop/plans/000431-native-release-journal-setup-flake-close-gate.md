---
gate: boundary-review
issue: 431
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d6b7649c-513d-4161-80fd-777ab12218a2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000431"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/a7dcd0c9c9a94aec
            reviewed_head: 838d439028664564b76a616cc5fcea7df4b0a55e
            slot: parley.nvim:1
            requested_at: "2026-10-24T09:53:49.14196Z"
          phase: finished
          pid: 85808
          started_at: "2026-10-24T09:53:49.242955Z"
          finished_at: "2026-10-24T09:59:20.039313Z"
          session_id: 8f01ef89-8ab6-4d2e-9990-e6188baf195b
          outcome: returned
      "n": 1
      timestamp: "2026-10-24T02:59:21-07:00"
      dispatched: "2026-10-24T02:53:49-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Spawn census and the vim.system-timeout lint each match one literal call form
          detail: 'There are two instances in this window. First, tests/arch/spawn_seam_spec.lua:225 counts helper spawns only in the inline require("parley.helper").system( form, so a local alias such as helper.system( would hide the spawn from the census. Second, tests/arch/deadline_timer_spec.lua:202-203 detects a forwarded options variable only when argv and opts are on the same line as vim.system, so a multi-line pcall(vim.system, argv, opts, cb) carrying a timeout would pass the lint. No current call site uses either form. Fix sketch: also match a local alias bound to require("parley.helper") followed by .system(, and apply the forwarded-variable regex to the joined window rather than the single line.'
          family: call-form-lint-misses-variant-forms
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 838d439028664564b76a616cc5fcea7df4b0a55e
      blocked: false
---

# Gate ledger — parley.nvim#431 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-24T02:59:21-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `call-form-lint-misses-variant-forms` (kind: defect) Spawn census and the vim.system-timeout lint each match one literal call form
  There are two instances in this window. First, tests/arch/spawn_seam_spec.lua:225 counts helper spawns only in the inline require("parley.helper").system( form, so a local alias such as helper.system( would hide the spawn from the census. Second, tests/arch/deadline_timer_spec.lua:202-203 detects a forwarded options variable only when argv and opts are on the same line as vim.system, so a multi-line pcall(vim.system, argv, opts, cb) carrying a timeout would pass the lint. No current call site uses either form. Fix sketch: also match a local alias bound to require("parley.helper") followed by .system(, and apply the forwarded-variable regex to the joined window rather than the single line.

## Open findings

- **BR-1** [Minor] `call-form-lint-misses-variant-forms` (kind: defect) Spawn census and the vim.system-timeout lint each match one literal call form
