---
gate: boundary-review
issue: 400
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 911c58ab-03f3-42b5-984e-dddd63e03545
            repository: github.com/xianxu/parley.nvim
            issue_id: "000400"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/637be2cad62ad5ba
            reviewed_head: 9d5d5f7586131f1f162f46fbfea75abe4d4f7f26
            slot: parley.nvim:3
            requested_at: "2026-10-19T19:36:39.794063Z"
          phase: finished
          pid: 28189
          started_at: "2026-10-19T19:36:39.898306Z"
          finished_at: "2026-10-19T19:56:26.078862Z"
          session_id: cce98557-87ad-433a-a7ac-5e56c2e22bc6
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9d5d5f7586131f1f162f46fbfea75abe4d4f7f26
        tracker_head: f5057134017dcb0a22c2211de4f1414f50826488
        branch_point: f5afbf45bf761ff0249f1e6a9d345ebe44814b1d
        since: "2026-10-19T12:01:16-07:00"
        until: "2026-10-19T12:36:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T12:01:16-07:00"
              end: "2026-10-19T12:36:13-07:00"
              began: "2026-10-19T12:01:16-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b9030abde3a242b84af551f6d154fb9f7423c17d4505f23cc46edb9765ed0ae0
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 8012686
              windows:
                - start: "2026-10-19T12:01:16-07:00"
                  end: "2026-10-19T12:36:13-07:00"
      "n": 1
      timestamp: "2026-10-19T12:56:34-07:00"
      dispatched: "2026-10-19T12:36:39-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: A timed-out status probe clears the band's owed state; the Spec says it keeps it
          detail: 'In session_sync.lua:405-420 a nil status (timeout) makes since nil, so s.owed gets set to nil and refresh(buf) drops the owed minutes. The Spec''s timeout table says the band keeps its last owed state. Family sweep: the actors query (:428) and own_slot behave as the Spec says; only the status query diverges. Fix: on nil status, clear s.probing and return before updating s.owed, and add a test that an owed band survives a status timeout. Or correct the Spec table.'
          family: spec-claim-diverges-from-code
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
          detail: 'couch.lua:14 reads require("parley.config") once at load time, while the registry and agentic_document submits use document_registry.config_ms (user override first). A user who raised the budget gets legacy submits killed and reported unconfirmed at 15 s. ARCH-DRY: resolve the default per call through a shared config_ms, and use the same value in the session_sync.lua:866 message.'
          family: config-read-single-source
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
          detail: Neovim sets code 124 whenever its timer fired and the exit code was 0 or 1, whatever the signal. Checking obj.code == 124 alone would be more robust. The real couch binary dies by the signal, so this is low impact.
          family: timeout-detection-predicate
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#400 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T12:56:34-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `spec-claim-diverges-from-code` (kind: defect) A timed-out status probe clears the band's owed state; the Spec says it keeps it
  In session_sync.lua:405-420 a nil status (timeout) makes since nil, so s.owed gets set to nil and refresh(buf) drops the owed minutes. The Spec's timeout table says the band keeps its last owed state. Family sweep: the actors query (:428) and own_slot behave as the Spec says; only the status query diverges. Fix: on nil status, clear s.probing and return before updating s.owed, and add a test that an owed band survives a status timeout. Or correct the Spec table.
- **BR-2** [Important] `config-read-single-source` (kind: defect) couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
  couch.lua:14 reads require("parley.config") once at load time, while the registry and agentic_document submits use document_registry.config_ms (user override first). A user who raised the budget gets legacy submits killed and reported unconfirmed at 15 s. ARCH-DRY: resolve the default per call through a shared config_ms, and use the same value in the session_sync.lua:866 message.
- **BR-3** [Minor] `timeout-detection-predicate` (kind: defect) couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
  Neovim sets code 124 whenever its timer fired and the exit code was 0 or 1, whatever the signal. Checking obj.code == 124 alone would be more robust. The real couch binary dies by the signal, so this is low impact.

## Open findings

- **BR-1** [Important] `spec-claim-diverges-from-code` (kind: defect) A timed-out status probe clears the band's owed state; the Spec says it keeps it
- **BR-2** [Important] `config-read-single-source` (kind: defect) couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
- **BR-3** [Minor] `timeout-detection-predicate` (kind: defect) couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
