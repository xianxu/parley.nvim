---
gate: boundary-review
issue: 322
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d59902d8-722f-40d2-b24f-b325f2ed3ba3
            repository: github.com/xianxu/parley.nvim
            issue_id: "000322"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/f41707648ce998dd
            reviewed_head: b2a6e58e990199e9f29dfa4044f1940272726564
            slot: parley.nvim:3
            requested_at: "2026-10-23T21:44:54.172256Z"
          phase: finished
          pid: 938
          started_at: "2026-10-23T21:44:54.325457Z"
          finished_at: "2026-10-23T21:47:55.015113Z"
          session_id: 01a16ab9-5abd-7e70-9d19-fbe6069bb14d
          outcome: returned
      "n": 1
      timestamp: "2026-10-23T14:47:56-07:00"
      dispatched: "2026-10-23T14:44:54-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Correct the attention-finder recording exclusion
          detail: 'atlas/ui/attention_finder.md:34 now says document submissions are not recorded, contradicting the preceding recording description and lua/parley/session_sync.lua:1137–1144, which records successful submitted-path deliveries. Replace this with a statement that local review requests are not recorded, or delete the bullet. Family instances introduced in this window: this one recording-exclusion claim.'
          family: documentation-matches-runtime
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: b2a6e58e990199e9f29dfa4044f1940272726564
      blocked: false
---

# Gate ledger — parley.nvim#322 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T14:47:56-07:00 (codex) — passed

### Raised

- **BR-1** [Minor] `documentation-matches-runtime` (kind: defect) Correct the attention-finder recording exclusion
  atlas/ui/attention_finder.md:34 now says document submissions are not recorded, contradicting the preceding recording description and lua/parley/session_sync.lua:1137–1144, which records successful submitted-path deliveries. Replace this with a statement that local review requests are not recorded, or delete the bullet. Family instances introduced in this window: this one recording-exclusion claim.

## Open findings

- **BR-1** [Minor] `documentation-matches-runtime` (kind: defect) Correct the attention-finder recording exclusion
